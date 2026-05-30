"""MkDocs hook: prettify auto-generated sidebar section titles.

Upstream chapter folders are named like ``06-retrieval-systems``. MkDocs auto-nav
uses the raw folder name as the section label. This rewrites section titles to a
readable form (``Retrieval Systems``) at build time, so the sidebar stays clean
AND fully auto-maintained — new upstream folders are prettified by rule, with no
hand-written nav. Additive overlay only: upstream content is never modified.
"""
import re

# Fix-ups applied after naive title-casing.
_ACRONYMS = {
    "Ai": "AI", "Mlops": "MLOps", "Llmops": "LLMOps", "Rag": "RAG",
    "Mcp": "MCP", "A2A": "A2A", "A2a": "A2A", "Llm": "LLM", "Api": "API", "Ui": "UI",
}
_SMALL = {"And", "Of", "To", "The", "In", "On", "For", "With", "A", "An", "Vs"}


def _pretty(name: str) -> str:
    s = re.sub(r"^\d+[-_]+", "", name)            # drop leading "06-"
    s = s.replace("-", " ").replace("_", " ").strip()
    out = []
    for i, w in enumerate(s.split()):
        t = w.title()
        if t in _ACRONYMS:
            t = _ACRONYMS[t]
        elif t in _SMALL and i != 0:
            t = t.lower()
        out.append(t)
    return " ".join(out) or name


def on_nav(nav, config, files):
    def walk(items):
        for item in items:
            if getattr(item, "is_section", False):
                item.title = _pretty(item.title)
                walk(item.children)
    walk(nav.items)
    return nav
