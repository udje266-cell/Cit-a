#!/usr/bin/env python3
"""Génère docs/CATALOG.md, docs/POWERS.md et docs/PROGRESSION.md à partir de data/*.json.
Usage : python3 tools/gen_docs.py  (depuis la racine du projet)"""
import json, os
R = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
J = lambda n: json.load(open(os.path.join(R, "data", n), encoding="utf-8"))
sp, tr, te, pw = J("species.json"), J("traits.json"), J("techs.json"), J("powers.json")
BIOMES = {"ocean":"Océan","lake":"Lac","ice":"Glacier","tundra":"Toundra","taiga":"Taïga","temperate_forest":"Forêt tempérée",
  "grassland":"Prairie","desert":"Désert","savanna":"Savane","rainforest":"Jungle","mountain":"Montagne","snow_peak":"Sommet enneigé"}
names = {t["id"]: t["name"] for t in tr["traits"]}

out = ["# Catalogue des espèces et des traits", "", "_Généré par `tools/gen_docs.py` depuis `data/`. Ne pas éditer à la main._", "",
       "## Espèces", "", "| Espèce | Longévité | Génération | Croissance | Magie | Milieux favoris | Description |", "|---|---|---|---|---|---|---|"]
for s in sp["species"]:
    hab = sorted(s["habitat"].items(), key=lambda x: -x[1])[:3]
    out.append(f"| {s['name']} | {s['longevity']} ans | {s['generation_years']} ans | {s['growth']*100:.1f} %/an | ×{s['magic_potential']} | "
               + ", ".join(BIOMES.get(h, h) for h, _ in hab) + f" | {s['desc']} |")
out += ["", f"## Traits ({len(tr['traits'])})", "",
        "Coût = points de création des fondateurs (négatif = rend des points). Héréditaire : transmis et soumis à la sélection ; acquis : culture.",
        "Les affinités Magie/Épée **ne sont pas des traits** (voir RULES.md §1).", ""]
for cid, cname in tr["categories"].items():
    out += [f"### {cname}", "", "| Trait | Type | Coût | Rareté (mutation) | Effets | Incompatible avec | Rôle |", "|---|---|---|---|---|---|---|"]
    for t in tr["traits"]:
        if t["cat"] != cid: continue
        fx = ", ".join(f"{k} {v:+.2f}" for k, v in t["fx"].items())
        inc = ", ".join(names[x] for x in t["incompat"]) or "—"
        kind = "héréditaire" if t["kind"] == "heritable" else "acquis"
        out.append(f"| {t['name']} | {kind} | {t['cost']} | {t['rarity']} | {fx} | {inc} | {t['desc']} |")
    out.append("")
out += ["## États temporaires", "", "| État | Effets | Description |", "|---|---|---|"]
for k, t in tr["temporary"].items():
    out.append(f"| {t['name']} | " + ", ".join(f"{a} {b:+.2f}" for a, b in t["fx"].items()) + f" | {t['desc']} |")
out += ["", "## Statistiques (abréviations)", "",
 "str force · end endurance · int intelligence · cur curiosité · soc sociabilité · coop coopération · agg agressivité · cou courage · spi spiritualité · "
 "mag aptitude à apprendre la magie · sci aptitude scientifique · fert fertilité · lon longévité · cold/heat/aqua/forest/mount/desert adaptation · "
 "disease résistance aux maladies · food efficacité alimentaire · craft artisanat."]
open(os.path.join(R, "docs", "CATALOG.md"), "w", encoding="utf-8").write("\n".join(out) + "\n")

out = ["# Catalogue des pouvoirs", "", "_Généré par `tools/gen_docs.py` depuis `data/powers.json`._", "",
       "Tous les pouvoirs se prévisualisent (zone surlignée + coût + conséquences différées + avertissements) avant validation.", ""]
for fid, fname in pw["families"].items():
    ps = [p for p in pw["powers"] if p["family"] == fid]
    out += [f"## {fname}", ""]
    if not ps:
        out += ["_Aucun pouvoir dans cette famille au jalon 1 (prévu)._", ""]; continue
    for p in ps:
        eff = ", ".join(f"{e['t']} {e.get('v')}" + (f" ({e['years']} ans)" if "years" in e else "") for e in p["effects"])
        dl = ", ".join(f"{e['t']} {e.get('v')} après {e['after']} ans" for e in p["delayed"]) or "aucune"
        unlock = "toujours disponible" if p.get("always_available") else f"niveau divin {p['unlock'].get('level', 0)}"
        cost = "variable (coût d'attribution tardive × nombre)" if p["id"] == "don_affinite" else p["cost"]
        out += [f"### {p['name']}", "", f"- **Coût** : {cost}", f"- **Déblocage** : {unlock}",
                f"- **Portée** : cible {'établissement' if p['target']=='settlement' else 'cellule'}, rayon {p['radius']} saut(s)",
                f"- **Effets immédiats** : {eff}", f"- **Conséquences différées** : {dl}", f"- **Effet visuel** : `{p['visual']}` (prévu : surbrillance de zone au jalon 1)",
                f"- **Interactions** : {p['interactions']}", f"- {p['desc']}", ""]
out += ["## Progression divine (accomplissements)", "", "| Objectif | Condition | XP |", "|---|---|---|"]
for a in pw["achievements"]:
    out.append(f"| {a['name']} | {a['desc']} | {a['xp']} |")
out += ["", "Seuils de niveau (XP) : " + ", ".join(str(x) for x in pw["level_xp"])]
open(os.path.join(R, "docs", "POWERS.md"), "w", encoding="utf-8").write("\n".join(out) + "\n")

out = ["# Progression science / magie", "", "_Généré par `tools/gen_docs.py` depuis `data/techs.json`._", "",
       "Voies : **commune**, **science**, **magie**, **hybride**. Chaque peuple a une orientation (−1 magie … +1 science) "
       "issue de sa divinité, puis infléchie par ses découvertes. Une époque est atteinte avec 2 découvertes de cette époque (1 pour l'âge astral).", ""]
PATH = {"common": "commune", "science": "science", "magic": "magie", "hybrid": "hybride"}
RES = {"wood":"bois","stone":"pierre","ore":"minerai","game":"gibier","fish":"poisson","mana":"cristaux de mana"}
tn = {t["id"]: t["name"] for t in te["techs"]}
for i, era in enumerate(te["eras"]):
    out += [f"## {i}. {era}", "", "| Découverte | Voie | Coût | Prérequis | Conditions | Effets |", "|---|---|---|---|---|---|"]
    for t in te["techs"]:
        if t["era"] != i: continue
        req = t["req"]; cond = []
        if req.get("resources"): cond.append("ressources : " + ", ".join(RES[r] for r in req["resources"]))
        if "min_stability" in req: cond.append(f"stabilité ≥ {req['min_stability']}")
        if "min_pop" in req: cond.append(f"population ≥ {req['min_pop']}")
        if "min_fertility" in req: cond.append(f"fertilité ≥ {req['min_fertility']}")
        if req.get("coastal"): cond.append("accès à la mer")
        for a, v in req.get("affinity", {}).items(): cond.append(f"porteurs {'Magie' if a=='magic' else 'Épée'} ≥ {v*100:.0f} %")
        fx = ", ".join(f"{k} +{v}" for k, v in t["fx"].items())
        if t.get("buildings"): fx += " ; bâtiments : " + ", ".join(t["buildings"])
        if t.get("culture"): fx += " ; culture : " + ", ".join(names.get(c, c) for c in t["culture"])
        out.append(f"| {t['name']} | {PATH[t['path']]} | {t['cost']} | {', '.join(tn[p] for p in t['prereq']) or '—'} | {'; '.join(cond) or '—'} | {fx} |")
    out.append("")
out += ["## Visuels par époque (jalon 1)", "", "0 tentes coniques · 1 huttes cubiques · 2 maisons à pignon · 3 tours · 4 flèches lumineuses · 5 cristaux/spires astrales.",
        "Prévu : variantes science (métal clair) / magie (cristaux violets) / hybride, routes, ports et véhicules."]
open(os.path.join(R, "docs", "PROGRESSION.md"), "w", encoding="utf-8").write("\n".join(out) + "\n")
print("docs générés")
