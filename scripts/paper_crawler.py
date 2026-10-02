#!/usr/bin/env python3
"""Polite metadata-only indexer for publicly linked exam papers. Does not download/store PDF bodies."""
import json,re,time,urllib.robotparser
from collections import deque
from urllib.parse import urljoin,urlparse,urldefrag,unquote
import requests
from bs4 import BeautifulSoup

UA="SGPaperIndexBot/1.0 (GitHub Pages public index; contact via repository issues)"
DELAY=1.5; MAX_PAGES_PER_SITE=12000; MAX_DEPTH=12
SITES={
 "sgexam":{"seeds":["https://sgexam.com/"],"hosts":{"sgexam.com","www.sgexam.com"},"allow":[r"^/$",r"^/primary-",r"^/subject/",r"^/year/",r"^/secondary/",r"^/gce/",r"^/paper/"],"deny":[r"^/wp-admin",r"^/wp-json",r"^/feed"]},
 "sgtestpaper":{"seeds":["https://www.sgtestpaper.com/","https://www.sgtestpaper.com/p6/"],"hosts":{"sgtestpaper.com","www.sgtestpaper.com"},"allow":[r"^/$",r"^/p[1-6]/",r"^/primary/",r"^/secondary/",r"^/gce/",r"^/free/",r"^/20\d{2}/",r"^/worksheet"],"deny":[r"^/shop",r"^/cart",r"^/checkout",r"^/my-account",r"^/wp-admin",r"^/wp-json"]},
 "testpapersfree":{"seeds":["https://www.testpapersfree.com/"],"hosts":{"testpapersfree.com","www.testpapersfree.com"},"allow":[r"^/"],"deny":[r"^/wp-admin",r"^/wp-json",r"^/cart",r"^/checkout",r"^/account",r"^/login"]},
 "sgexams":{"seeds":["https://www.sgexams.com/"],"hosts":{"sgexams.com","www.sgexams.com"},"allow":[r"^/$",r"^/download/",r"^/primary/",r"^/secondary/",r"^/subject/",r"^/year/"],"deny":[r"^/admin",r"^/login",r"^/api/"]}
}
SUBJECTS=[("Higher Chinese",r"higher\s*chinese|hcl"),("Chinese",r"chinese|中文|华文"),("English",r"english"),("E-Math",r"e[- ]?math|elementary mathematics"),("A-Math",r"a[- ]?math|additional mathematics"),("Maths",r"maths?|mathematics"),("Combined Science",r"combined science"),("Science",r"science"),("Physics",r"physics"),("Chemistry",r"chemistry"),("Biology",r"biology"),("Social Studies",r"social studies"),("Geography",r"geography"),("History",r"history")]
EXAMS=[("PRELIM",r"prelim"),("EOY",r"end.?of.?year|\beoy\b"),("SA2",r"\bsa2\b"),("SA1",r"\bsa1\b"),("WA3",r"\bwa3\b"),("WA2",r"\bwa2\b"),("WA1",r"\bwa1\b"),("PSLE",r"psle")]
robots={}
def clean(u):
 u,_=urldefrag(u);return u
def norm(s):return re.sub(r"\s+"," ",re.sub(r"[_+.%/-]+"," ",unquote(str(s or "")).lower())).strip()
def meta(title,pdf,page,site):
 blob=norm(" ".join([title,pdf,page]));m=re.search(r"\b(?:p|primary)[ _-]?([1-6])\b",blob);level="P"+m.group(1) if m else (("Sec"+re.search(r"sec(?:ondary)?[ _-]?([1-5])",blob).group(1)) if re.search(r"sec(?:ondary)?[ _-]?([1-5])",blob) else ("JC"+re.search(r"jc[ _-]?([12])",blob).group(1) if re.search(r"jc[ _-]?([12])",blob) else "Unknown"))
 subject=next((n for n,p in SUBJECTS if re.search(p,blob,re.I)),"Unknown")
 years=re.findall(r"\b(19\d{2}|20\d{2})\b",blob);year=max(map(int,years),default=0)
 exam=next((n for n,p in EXAMS if re.search(p,blob,re.I)),"Unknown")
 schools=["Nanyang","Raffles","Rosyth","Tao Nan","Nan Hua","St Hilda","Pei Hwa","Pei Chun","Henry Park","Rulang","Catholic High","Anglo Chinese","Methodist Girls","Ai Tong","CHIJ","St Nicholas","Red Swastika","Maris Stella","Nan Chiau","River Valley","Temasek","Cedar","Dunman","Victoria","Hwa Chong"]
 school=next((x for x in sorted(schools,key=len,reverse=True) if x.lower() in blob),"Unknown")
 return {"title":title or unquote(urlparse(pdf).path.rsplit("/",1)[-1]) or "Exam paper","level":level,"subject":subject,"year":year,"school":school,"exam":exam,"pdf_url":pdf,"source_page":page,"source_site":site}
def allowed(u,c):
 p=urlparse(u)
 if p.scheme not in ("http","https") or p.hostname not in c["hosts"]:return False
 if any(re.search(x,p.path,re.I) for x in c["deny"]):return False
 # Keep site pages and pagination; reject obvious account/search/filter traps.
 if re.search(r"/(wp-admin|wp-json|login|register|cart|checkout|account)(/|$)",p.path,re.I):return False
 if len(p.query)>220:return False
 return True
def is_pdf(u,ct=""):
 return "application/pdf" in ct.lower() or urlparse(u).path.lower().endswith(".pdf") or ("drive.google.com" in urlparse(u).netloc and ("/file/d/" in urlparse(u).path or "export=download" in urlparse(u).query))
def can_fetch(u):
 p=urlparse(u);root=p.scheme+"://"+p.netloc
 if root not in robots:
  rp=urllib.robotparser.RobotFileParser();rp.set_url(root+"/robots.txt")
  try:rp.read();robots[root]=rp
  except Exception:
   print("robots unavailable; skipping host",root);robots[root]=False
 return robots[root] is not False and robots[root].can_fetch(UA,u)
def sitemap_urls(session,root):
 urls=[]
 try:
  r=session.get(root+"/robots.txt",timeout=18);r.raise_for_status()
  urls += re.findall(r"(?im)^\\s*Sitemap:\\s*(\\S+)",r.text)
 except requests.RequestException:pass
 urls += [root+"/sitemap.xml",root+"/wp-sitemap.xml",root+"/sitemap_index.xml"]
 seen=set();todo=deque(urls);pages=0
 while todo and pages<80:
  sm=todo.popleft()
  if sm in seen:continue
  seen.add(sm)
  try:
   r=session.get(sm,timeout=20);r.raise_for_status()
   if "xml" not in r.headers.get("content-type","").lower() and not r.text.lstrip().startswith("<?xml"):continue
   soup=BeautifulSoup(r.content,"xml");pages+=1
   for loc in soup.find_all("loc"):
    u=clean(loc.get_text(strip=True))
    if is_pdf(u):yield u
    elif urlparse(u).hostname==urlparse(root).hostname and (u.lower().endswith(".xml") or "sitemap" in u.lower()):todo.append(u)
    elif urlparse(u).hostname==urlparse(root).hostname:yield "PAGE:"+u
  except Exception as e:print("sitemap skip",sm,str(e)[:100])
def crawl():
 session=requests.Session();session.headers.update({"User-Agent":UA,"Accept":"text/html,application/xhtml+xml,application/xml,application/pdf;q=0.8,*/*;q=0.5"})
 found={}
 for site,cfg in SITES.items():
  root=cfg["seeds"][0].rstrip("/")
  q=deque((u,0) for u in cfg["seeds"]);seen=set(cfg["seeds"]);count=0
  # Sitemap URLs expose deep archives that homepage crawling may never reach.
  for item in sitemap_urls(session,root):
   if item.startswith("PAGE:"):
    u=item[5:]
    if allowed(u,cfg) and u not in seen:seen.add(u);q.append((u,0))
   else:
    found.setdefault(item,meta(unquote(urlparse(item).path.rsplit("/",1)[-1]),item,item,site))
  while q and count<MAX_PAGES_PER_SITE:
   u,depth=q.popleft()
   if not can_fetch(u):continue
   try:r=session.get(u,timeout=22,allow_redirects=True);r.raise_for_status()
   except requests.RequestException as e:print("skip",u,str(e)[:160]);continue
   count+=1;ct=r.headers.get("content-type","")
   if is_pdf(r.url,ct):
    found.setdefault(clean(r.url),meta(unquote(urlparse(r.url).path.rsplit("/",1)[-1]),clean(r.url),u,site));continue
   if "html" not in ct and not r.text.lstrip().startswith("<"):continue
   soup=BeautifulSoup(r.text,"html.parser");title=(soup.title.get_text(" ",strip=True) if soup.title else "") or (soup.h1.get_text(" ",strip=True) if soup.h1 else "")
   canonical=soup.find("link",rel=lambda v:v and "canonical" in v)
   if canonical and canonical.get("href"):
    can=clean(urljoin(r.url,canonical["href"]))
    if is_pdf(can):found.setdefault(can,meta(title,can,r.url,site))
   for a in soup.find_all("a",href=True):
    link=clean(urljoin(r.url,a["href"].strip()));anchor=a.get_text(" ",strip=True)
    if is_pdf(link):
     found.setdefault(link,meta(anchor or title,link,r.url,site))
    elif depth<MAX_DEPTH and link not in seen and allowed(link,cfg):
     seen.add(link);q.append((link,depth+1))
   time.sleep(DELAY)
  print(site,"pages",count,"indexed",sum(x["source_site"]==site for x in found.values()))
 out=sorted(found.values(),key=lambda x:(-int(x.get("year") or 0),x["level"],x["subject"],x["school"],x["title"]))
 with open("exam-papers/papers.json","w",encoding="utf-8") as f:json.dump(out,f,ensure_ascii=False,indent=2)
 print("saved",len(out),"records")
if __name__=="__main__":crawl()
