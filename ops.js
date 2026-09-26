const s=supabase.createClient(SUPABASE_CONFIG.url,SUPABASE_CONFIG.anonKey);
let C=[],N=[],A=[],F='all',P=[],T=[];
const E=x=>String(x??'').replace(/[&<>\"]/g,z=>({'&':'&amp;','<':'&lt;','>':'&gt;','\"':'&quot;'}[z]));
const SG=x=>new Intl.DateTimeFormat('en-CA',{timeZone:'Asia/Singapore'}).format(new Date(x));
const dayDiff=x=>Math.round((new Date(SG(x)+'T00:00:00+08:00')-new Date(SG(Date.now())+'T00:00:00+08:00'))/864e5);
const daysSince=x=>x?Math.max(0,Math.floor((Date.now()-new Date(x).getTime())/864e5)):999;
const S=x=>({new:'一方有兴趣',both_interested:'双方有兴趣',contacting:'沟通中',trial:'试听中',confirmed:'已成交',not_concluded:'未成交',cancelled:'已取消'}[x]||x);
const terminal=x=>['confirmed','cancelled','not_concluded'].includes(x);
const today=()=>SG(Date.now());
function boot(){s.auth.getUser().then(async({data:{user}})=>{if(!user){msg.textContent='请先登录平台后台';return}const{data:a,error}=await s.from('platform_admins').select('user_id,display_name,active').eq('user_id',user.id).maybeSingle();if(error||!a?.active){msg.textContent='当前账号没有管理员权限';return}msg.remove();app.classList.remove('hidden');me.textContent='当前登录：'+(a.display_name||user.email);load()})}
async function load(){
 stamp.textContent='刷新：'+new Date().toLocaleString('zh-SG',{hour12:false});
 const[cr,nr,ar,pr,tr]=await Promise.all([
  s.from('match_cases').select('id,status,last_contacted_at,created_at,parent_request_id,tutor_id,parent_requests(contact_name,subject,level,request_status),tutor_profiles(name,tutor_status)').order('created_at',{ascending:false}),
  s.from('match_case_notes').select('id,match_case_id,admin_user_id,note,next_action,next_action_at,completed_at,created_at').order('created_at',{ascending:false}),
  s.from('platform_admins').select('user_id,display_name,active').eq('active',true),
  s.from('parent_requests').select('id,request_status,created_at'),
  s.from('tutor_profiles').select('id,tutor_status,created_at')
 ]);
 C=cr.data||[];N=nr.data||[];A=ar.data||[];P=pr.data||[];T=tr.data||[];render();
}
function openTasks(){return N.filter(n=>n.next_action_at&&!n.completed_at)}
function render(){renderKpi();renderFunnel();renderPending();renderAdmins();renderStale();renderTasks()}
function renderKpi(){
 const open=openTasks(),d=today(),plannedToday=N.filter(n=>n.next_action_at&&SG(n.next_action_at)===d),completedToday=N.filter(n=>n.completed_at&&SG(n.completed_at)===d),completedPlannedToday=plannedToday.filter(n=>n.completed_at&&SG(n.completed_at)===d).length,rate=plannedToday.length?Math.round(completedPlannedToday/plannedToday.length*100):null,overdue=open.filter(n=>dayDiff(n.next_action_at)<0).length,risk=C.filter(c=>staleCase(c)).length,activeCases=C.filter(c=>!terminal(c.status)).length,confirmed=C.filter(c=>c.status==='confirmed').length;
 kpi.innerHTML=[['🎯',rate===null?'—':rate+'%','今日完成率'],['✓',completedToday.length,'今日完成跟进'],['🔴',overdue,'当前逾期未跟进'],['⚠️',risk,'连续未跟进案例'],['🔄',activeCases,'进行中撮合'],['💰',confirmed,'累计已成交案例']].map(x=>'<div class="stat"><b>'+x[0]+' '+x[1]+'</b><span>'+x[2]+'</span></div>').join('');
}
function renderFunnel(){
 const total=C.length||1,steps=[['new','有兴趣',C.filter(c=>c.status==='new').length],['both_interested','双方有兴趣',C.filter(c=>c.status==='both_interested').length],['contacting','沟通中',C.filter(c=>c.status==='contacting').length],['trial','试听中',C.filter(c=>c.status==='trial').length],['confirmed','已成交',C.filter(c=>c.status==='confirmed').length]],base=Math.max(1,steps.reduce((s,x)=>s+x[2],0));
 funnel.innerHTML=steps.map((x,i)=>{const pct=Math.round(x[2]/base*100),prev=i?steps[i-1][2]:x[2],cv=i&&prev?Math.round(x[2]/prev*100):100;return '<div class="row"><div style="min-width:125px"><b>'+x[1]+'</b><div class="mini">阶段转化 '+cv+'%</div></div><div style="flex:1"><div class="bar"><i style="width:'+Math.min(100,pct)+'%"></i></div></div><b>'+x[2]+'</b></div>'}).join('')+'<div class="mini" style="margin-top:10px">总成交率：'+Math.round(steps[4][2]/base*100)+'% · 未成交 '+C.filter(c=>c.status==='not_concluded').length+' · 已取消 '+C.filter(c=>c.status==='cancelled').length+'</div>';
}
function renderPending(){
 const activeParents=P.filter(x=>x.request_status==='active').length,activeTutors=T.filter(x=>x.tutor_status==='active').length,parentOpenCases=C.filter(c=>!terminal(c.status)).map(c=>c.parent_request_id).filter((v,i,a)=>a.indexOf(v)===i).length,tutorOpenCases=C.filter(c=>!terminal(c.status)).map(c=>c.tutor_id).filter((v,i,a)=>a.indexOf(v)===i).length;
 pending.innerHTML='<div class="row"><div><b>👨‍👩‍👧 家长待处理需求</b><div class="mini">仍开放的家长 request</div></div><b>'+activeParents+'</b></div><div class="row"><div><b>👨‍🏫 老师待处理</b><div class="mini">参与进行中撮合的老师</div></div><b>'+tutorOpenCases+'</b></div><div class="row"><div><b>🔗 家长进行中案例</b><div class="mini">去重后的活跃家长</div></div><b>'+parentOpenCases+'</b></div><div class="row"><div><b>🧑‍🏫 当前可接单老师</b><div class="mini">active tutor profiles</div></div><b>'+activeTutors+'</b></div>';
}
function renderAdmins(){
 const d=today(),allAdmins=A.length?A:[...new Map(N.map(n=>[n.admin_user_id,{user_id:n.admin_user_id,display_name:null}])).values()];
 if(!allAdmins.length){admins.innerHTML='<div class="empty">暂无管理员跟进记录。</div>';return}
 admins.innerHTML=allAdmins.map(a=>{const mine=N.filter(n=>n.admin_user_id===a.user_id),created=mine.filter(n=>SG(n.created_at)===d).length,done=mine.filter(n=>n.completed_at&&SG(n.completed_at)===d).length,open=mine.filter(n=>n.next_action_at&&!n.completed_at).length;return '<div class="row"><div><b>'+E(a.display_name||('管理员 '+String(a.user_id||'').slice(0,8)))+'</b><div class="mini">今日跟进 '+created+' · 今日完成 '+done+' · 未完成 '+open+'</div></div><span class="badge '+(open>5?'warn':'ok')+'">'+created+' 次</span></div>'}).join('')+(A.length<=1?'<div class="mini" style="margin-top:10px">若这里没有显示全部管理员姓名，请运行仓库中的 ops-supervisor-schema.sql，开放管理员之间的主管只读权限。</div>':'');
}
function staleCase(c){if(terminal(c.status))return false;const hasOpen=openTasks().some(n=>n.match_case_id===c.id);if(hasOpen)return false;return daysSince(c.last_contacted_at||c.created_at)>=3}
function renderStale(){
 const rows=C.filter(staleCase).sort((a,b)=>daysSince(b.last_contacted_at||b.created_at)-daysSince(a.last_contacted_at||a.created_at));
 if(!rows.length){stale.innerHTML='<div class="empty">🎉 没有连续 3 天以上未跟进的开放案例。</div>';return}
 stale.innerHTML=rows.slice(0,12).map(c=>{const d=daysSince(c.last_contacted_at||c.created_at),p=c.parent_requests||{},t=c.tutor_profiles||{};return '<div class="row"><div><b>'+E(p.contact_name||'-')+' ↔ '+E(t.name||'-')+'</b><div class="mini">#'+c.id+' · '+E(p.subject||'-')+' · '+E(S(c.status))+'</div></div><span class="badge danger">'+d+' 天</span></div>'}).join('');
}
function setFilter(x){F=x;renderTasks()}
function taskBucket(n){if(F==='risk')return C.some(c=>c.id===n.match_case_id&&staleCase(c));if(!n.next_action_at)return false;const d=dayDiff(n.next_action_at);if(F==='overdue')return d<0;if(F==='today')return d===0;if(F==='next7')return d>=0&&d<=7;return true}
function renderTasks(){
 const open=openTasks();let rows=open.filter(taskBucket);if(F==='risk')rows=open.filter(n=>C.some(c=>c.id===n.match_case_id&&staleCase(c)));rows.sort((a,b)=>new Date(a.next_action_at)-new Date(b.next_action_at));
 if(!rows.length){tasks.innerHTML='<div class="empty">🎉 当前筛选没有待处理任务。</div>';return}
 tasks.innerHTML=rows.slice(0,40).map(n=>{const c=C.find(x=>x.id===n.match_case_id)||{},p=c.parent_requests||{},t=c.tutor_profiles||{},d=dayDiff(n.next_action_at),tag=d<0?'🔴逾期':d===0?'🟠今天':'📅后续';return '<div class="row"><div><b>'+E(p.contact_name||'-')+' ↔ '+E(t.name||'-')+'</b><div class="mini">#'+n.match_case_id+' · '+E(p.subject||'-')+' · '+E(S(c.status))+' · '+E(n.note||'-')+'</div><div><b>➡ '+E(n.next_action||'建立下一步')+'</b> <span class="mini">'+tag+' · '+new Date(n.next_action_at).toLocaleString('zh-SG',{hour12:false})+'</span></div></div><button onclick="done('+n.id+')">✓完成</button></div>'}).join('');
}
async function done(id){const{error}=await s.from('match_case_notes').update({completed_at:new Date().toISOString()}).eq('id',id);if(error){alert(error.message);return}await load()}
boot();