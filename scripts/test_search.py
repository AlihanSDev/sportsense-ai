#!/usr/bin/env python3
"""
Тест поиска в интернете через LangChain + DuckDuckGo.
Проверяет каждый шаг инициализации и поиска.
"""

import sys

print("=" * 60)
print("TEST 1: LangChain import")
print("=" * 60)
try:
    from langchain_community.utilities import DuckDuckGoSearchAPIWrapper
    print("✅ langchain_community imported successfully")
    LANGCHAIN_OK = True
except ImportError as e:
    print(f"❌ langchain_community NOT available: {e}")
    LANGCHAIN_OK = False
except Exception as e:
    print(f"❌ Unexpected error: {e}")
    LANGCHAIN_OK = False

print()
print("=" * 60)
print("TEST 2: Check duckduckgo-search package")
print("=" * 60)
try:
    from duckduckgo_search import DDGS
    print("✅ duckduckgo_search imported successfully")
    DDGS_OK = True
except ImportError as e:
    print(f"❌ duckduckgo_search NOT available: {e}")
    DDGS_OK = False
except Exception as e:
    print(f"❌ Unexpected error: {e}")
    DDGS_OK = False

print()
print("=" * 60)
print("TEST 3: Direct DuckDuckGo search (no LangChain)")
print("=" * 60)
if DDGS_OK:
    try:
        with DDGS() as ddgs:
            results = list(ddgs.text("Barcelona FC 2026", max_results=3))
        print(f"✅ Direct DDG search: {len(results)} results")
        for i, r in enumerate(results, 1):
            print(f"  [{i}] {r.get('title', 'N/A')}")
            print(f"      {r.get('href', 'N/A')}")
    except Exception as e:
        print(f"❌ Direct DDG search failed: {e}")
else:
    print("⏭️ Skipped (duckduckgo_search not available)")

print()
print("=" * 60)
print("TEST 4: LangChain DuckDuckGoSearchAPIWrapper")
print("=" * 60)
if LANGCHAIN_OK:
    try:
        search = DuckDuckGoSearchAPIWrapper(max_results=3)
        print("✅ DuckDuckGoSearchAPIWrapper created")
        
        print("  Searching: Barcelona FC 2026...")
        results = search.results("Barcelona FC 2026")
        print(f"✅ Search returned {len(results)} results")
        for i, r in enumerate(results, 1):
            print(f"  [{i}] Title: {r.get('title', 'N/A')}")
            print(f"      Snippet: {r.get('snippet', 'N/A')[:100]}...")
            print(f"      Link: {r.get('link', 'N/A')}")
    except Exception as e:
        print(f"❌ LangChain search failed: {e}")
        import traceback
        traceback.print_exc()
else:
    print("⏭️ Skipped (langchain not available)")

print()
print("=" * 60)
print("SUMMARY")
print("=" * 60)
print(f"  LangChain: {'✅' if LANGCHAIN_OK else '❌'}")
print(f"  duckduckgo_search: {'✅' if DDGS_OK else '❌'}")
print()
if not LANGCHAIN_OK and not DDGS_OK:
    print("FIX: pip install langchain langchain-community duckduckgo-search")
elif not DDGS_OK:
    print("FIX: pip install duckduckgo-search")
else:
    print("All packages available. Search should work.")
