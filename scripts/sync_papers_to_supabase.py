#!/usr/bin/env python3
"""Upsert crawled exam-paper metadata into Supabase; never uploads PDF bodies."""
import json, os, sys, requests

url=os.environ["SUPABASE_URL"].rstrip("/")
key=os.environ["SUPABASE_SERVICE_ROLE_KEY"]
with open("exam-papers/papers.json",encoding="utf-8") as f:
    rows=json.load(f)
payload=[]
for r in rows:
    pdf=(r.get("pdf_url") or "").strip()
    if not pdf: continue
    payload.append({
        "source_site":r.get("source_site") or "unknown",
        "title":r.get("title") or "Exam paper",
        "level":r.get("level") or "Unknown",
        "subject":r.get("subject") or "Unknown",
        "year":int(r["year"]) if str(r.get("year","")).isdigit() and int(r["year"])>0 else None,
        "school":r.get("school") or "Unknown",
        "exam_type":r.get("exam") or "Unknown",
        "pdf_url":pdf,
        "source_page":r.get("source_page"),
        "metadata":{}
    })
headers={"apikey":key,"Authorization":"Bearer "+key,"Content-Type":"application/json","Prefer":"resolution=merge-duplicates,return=minimal"}
total=0
for i in range(0,len(payload),250):
    batch=payload[i:i+250]
    response=requests.post(url+"/rest/v1/exam_papers?on_conflict=pdf_url",headers=headers,json=batch,timeout=60)
    if not response.ok:
        print("Supabase upsert failed:",response.status_code,response.text[:1500],file=sys.stderr)
        response.raise_for_status()
    total+=len(batch)
print(f"Upserted {total} indexed metadata records to Supabase.")
