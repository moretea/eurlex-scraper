#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3Packages.beautifulsoup4
from bs4 import BeautifulSoup
import sys
import csv
import glob
import sys

def attempt_or_none(f):
    try:
        return f()
    except:
        return None

def process(f, writer):
    print(f"Processing {f}",file=sys.stderr)
    with open(f) as fp:
        soup = BeautifulSoup(fp, "html.parser")
        all_text_lines = [x.strip() for x in soup.find("div", id="document1").text.split("\n")]


        v1_eur_lex_code = f.split("/")[-1].split(".")[0]
        v2_interinst_code = attempt_or_none(lambda: soup.find("div", {"id": "PPProc_Contents"}).find("a").text )
        v3_com_doc_id = soup.find("div", {"id": "PP1Contents"}).find_all("p")[-1].text
        v4_doc_name = soup.find("p", {"id": "englishTitle"}).text
        v5_link_proposal = "https://eur-lex.europa.eu/legal-content/EN/ALL/?uri=CELEX:"+v1_eur_lex_code
        nmetadata = soup.find("div", id="PPDates_Contents").find_all("dl", class_="NMetadata")
        v6_com_proposal_date = [x for x in soup.find("div", id="PPDates_Contents").find_all("dt") if x.text.strip() == "Date of document:"][0].find_next_sibling("dd").text
        v7_policycontent_dircode = [x for x in soup.find("div", id="PPClass_Contents").find_all("dt") if x.text.strip() == "Directory code:"][0].find_next_sibling("dd").find("li").text.strip().replace("\n", " ")
        v8_policy_scope =  len([x for x in soup.find("div", id="PPClass_Contents").find_all("dt") if x.text.strip() == "EUROVOC descriptor:"][0].find_next_sibling("dd").find_all("li"))
        v9_comdg = [x for x in soup.find("div", id="PPMisc_Contents").find_all("dt") if x.text.strip() == "Department responsible:"][0].find_next_sibling("dd").text.strip()
        v10_legprocedure = attempt_or_none(lambda: [x for x in soup.find("div", id="PPProc_Contents").find_all("dt") if x.text.strip() == "Procedure number:"][0].find_next_sibling("dd").text.strip().split("/")[-1])
        v11_typeinstrument = [x for x in soup.find("div", id="PPMisc_Contents").find_all("dt") if x.text.strip() == "Form:"][0].find_next_sibling("dd").text.strip()
        
        v17_recitals = None
        state = "nope"
        for line in all_text_lines:
            if state == "nope" and line == "Whereas:":
                v17_recitals = 0
                state = "counting"
            elif state == "counting":
                if len(line) > 3 and line[0] == '(' and line[2] == ')':
                    v17_recitals += 1
                elif line == "":
                    continue
                else:
                    state = "fini"

        v18_articles = len(soup.find_all("p", class_="Titrearticle"))
        fulltext = soup.find("div", id="document1").find("div", class_="contentWrapper").text.lower()
        v19_delegated = "delegated" in fulltext
        v20_impl_adv = "implementing" in fulltext

        writer.writerow([v1_eur_lex_code, v2_interinst_code, v3_com_doc_id, v4_doc_name, v5_link_proposal, v6_com_proposal_date, v7_policycontent_dircode, v8_policy_scope, v9_comdg, v10_legprocedure, v11_typeinstrument, v17_recitals, v18_articles, v19_delegated, v20_impl_adv])

writer = csv.writer(sys.stdout, delimiter=',', quotechar='"', quoting=csv.QUOTE_MINIMAL)
writer.writerow(["V1_EUR-Lex code", "V2_interinst_code", "V3_COM_Doc_id",       "V4_Doc_Name",         "V5_Link_proposal",          "V6_COM_Proposal_Date", "V7_PolicyContent_dircode", "V8_Policy_scope",            "V9_ComDG",               "V10_LegProcedure",                         "V11_TypeInstrument", "V17_recitals",                                               "V18_articles",                                                    "V19_delegated",                                "V20_impl_adv"])

for f in sorted(glob.glob("data/**/html/*.html")):
    #if f < "data/2021/html/":
    #    continue
    try:
        process(f, writer)
    except Exception as e:
        print(f"Fout bij {f}:", e, file=sys.stderr)

