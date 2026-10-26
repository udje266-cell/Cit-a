#!/usr/bin/env python3
"""Inventaire des textes à traduire et couverture d'une langue.

  python3 tools/extract_strings.py            -> écrit data/i18n/_a_traduire_<langue>.json (textes sans traduction)
  python3 tools/extract_strings.py --stats    -> couverture seulement

Sources : textes littéraux de l'interface (game/*.gd : boutons, étiquettes, messages, tr(...)),
noms et descriptions du catalogue (data/*.json : pouvoirs, familles, traits, techniques, espèces, objectifs).
Les clés sont les textes français exacts ; les fichiers data/i18n/<langue>.json associent chaque clé à sa traduction.
"""
import json, re, glob, sys, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LANGS = ["en"]
# Appels dont le premier argument texte est affiché tel quel ou via tr().
CALLS = r'(?:tr|_button|_rich|show_message|show_toast|_label|set_tutorial|add_item|open_modal)\(\s*"((?:[^"\\]|\\.)+)"'
ASSIGN = r'\.(?:text|tooltip_text|placeholder_text|title)\s*=\s*"((?:[^"\\]|\\.)+)"'
APPEND = r'\bt \+= tr\("((?:[^"\\]|\\.)+)"\)'

def ui_strings():
    out = set()
    for f in glob.glob(os.path.join(ROOT, "game", "*.gd")):
        src = open(f, encoding="utf-8").read()
        for rx in (CALLS, ASSIGN, APPEND):
            for m in re.finditer(rx, src):
                s = m.group(1).encode().decode("unicode_escape").encode("latin-1").decode("utf-8")
                # Écarte les identifiants techniques (un seul mot en minuscules, noms de classes).
                if re.search(r"[A-Za-zÀ-ÿ]{3}", s) and not re.fullmatch(r"[a-z_]+|[A-Z][a-z]+[A-Z]\w*", s):
                    out.add(s)
        # Tableaux de textes (tutoriel, rail).
        for m in re.finditer(r'const TUTORIAL := \[(.*?)\n\]', src, re.S):
            for t in re.findall(r'"((?:[^"\\]|\\.)+)"', m.group(1)):
                out.add(t)
    return out

# Dictionnaires de libellés affichés via tr(...) : (fichier, nom de la constante).
CONST_DICTS = [("sim/affinity.gd", "NAMES"), ("sim/planet.gd", "BIOME_NAMES"), ("sim/planet.gd", "RES_NAMES"),
               ("game/ui.gd", "FAMILY_SHORT")]

def const_strings():
    out = set()
    for f, name in CONST_DICTS:
        src = open(os.path.join(ROOT, f), encoding="utf-8").read()
        m = re.search(r"const %s := \{(.*?)\}" % name, src, re.S)
        if m:
            out.update(re.findall(r'"\w+":\s*"([^"]+)"', m.group(1)))
    # Libellés du rail, régimes politiques, épisodes climatiques.
    ui = open(os.path.join(ROOT, "game", "ui.gd"), encoding="utf-8").read()
    out.update(re.findall(r'\["\w+", "\w+", "([^"]+)", ', ui))
    civ = open(os.path.join(ROOT, "sim", "civ_system.gd"), encoding="utf-8").read()
    out.update(re.findall(r'polity :?= "([^"]+)"', civ))
    cl = open(os.path.join(ROOT, "sim", "climate.gd"), encoding="utf-8").read()
    out.update(re.findall(r'"name": "([^"]+)"', cl))
    return out

def data_strings():
    out = set()
    d = json.load(open(os.path.join(ROOT, "data", "powers.json"), encoding="utf-8"))
    out.update(d["families"].values())
    for p in d["powers"]:
        out.update([p["name"], p["desc"], p["interactions"]])
    for a in d["achievements"]:
        out.update([a["name"], a["desc"]])
    t = json.load(open(os.path.join(ROOT, "data", "traits.json"), encoding="utf-8"))
    for tr in t["traits"].values() if isinstance(t["traits"], dict) else t["traits"]:
        out.add(tr["name"])
        if tr.get("desc"):
            out.add(tr["desc"])
    for v in t["temporary"].values():
        out.update([v["name"], v["desc"]])
    te = json.load(open(os.path.join(ROOT, "data", "techs.json"), encoding="utf-8"))
    for x in (te["techs"] if isinstance(te, dict) else te):
        out.add(x["name"])
    sp = json.load(open(os.path.join(ROOT, "data", "species.json"), encoding="utf-8"))
    for x in (sp["species"].values() if isinstance(sp.get("species"), dict) else sp.get("species", [])):
        out.add(x["name"])
        if x.get("desc"):
            out.add(x["desc"])
    out.update(te.get("eras", []) if isinstance(te, dict) else [])
    out.update(t.get("categories", {}).values())
    return out

def main():
    ui, data = ui_strings() | const_strings(), data_strings()
    ui = {k for k in ui if not re.fullmatch(r"[a-z_]+|[A-Z][a-z]+[A-Z]\w*", k)}
    allk = ui | data
    for lang in LANGS:
        path = os.path.join(ROOT, "data", "i18n", lang + ".json")
        tr = json.load(open(path, encoding="utf-8")) if os.path.exists(path) else {}
        miss_ui = sorted(k for k in ui if k not in tr)
        miss_data = sorted(k for k in data if k not in tr)
        print(f"{lang} : interface {len(ui) - len(miss_ui)}/{len(ui)} · catalogue {len(data) - len(miss_data)}/{len(data)} · "
              f"total {100.0 * (len(allk) - len(set(miss_ui) | set(miss_data))) / max(len(allk), 1):.0f} %")
        if "--stats" not in sys.argv:
            with open(os.path.join(ROOT, "data", "i18n", f"_a_traduire_{lang}.json"), "w", encoding="utf-8") as f:
                json.dump({"interface": miss_ui, "catalogue": miss_data}, f, ensure_ascii=False, indent=1)

if __name__ == "__main__":
    main()
