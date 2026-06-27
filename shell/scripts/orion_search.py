#!/usr/bin/env python3
import sys
import argparse
from playwright.sync_api import sync_playwright

def search_web(query, page_num):
    with sync_playwright() as p:
        try:
            browser = p.firefox.launch(headless=True)
            page = browser.new_page()
            
            start_index = (page_num - 1) * 5
            page.goto(f"https://html.duckduckgo.com/html/?q={query}")
            
            results = []
            elements = page.query_selector_all(".result")
            
            start_idx = (page_num - 1) * 5
            end_idx = start_idx + 5
            
            for i, el in enumerate(elements):
                if i < start_idx: continue
                if i >= end_idx: break
                
                title_el = el.query_selector(".result__title")
                snippet_el = el.query_selector(".result__snippet")
                url_el = el.query_selector(".result__url")
                
                title = title_el.inner_text().strip() if title_el else ""
                snippet = snippet_el.inner_text().strip() if snippet_el else ""
                url = url_el.inner_text().strip() if url_el else ""
                
                if url and not url.startswith("http"):
                    url = "https://" + url
                
                if title and url:
                    results.append(f"Title: {title}\nURL: {url}\nSnippet: {snippet}")
            
            browser.close()
            
            if not results:
                return "No useful results found for this page."
            
            return "\n\n".join(results)
            
        except Exception as e:
            return f"Error during web search: {str(e)}"

def read_webpage(url):
    with sync_playwright() as p:
        try:
            browser = p.firefox.launch(headless=True)
            page = browser.new_page()
            page.goto(url, timeout=15000)
            
            # Extract main text body, strip scripts and styles
            text = page.evaluate('''() => {
                const elementsToRemove = document.querySelectorAll('script, style, nav, footer, header, aside');
                elementsToRemove.forEach(el => el.remove());
                return document.body.innerText;
            }''')
            
            browser.close()
            
            # Truncate text to avoid blowing up the context window
            text = text.strip()
            if len(text) > 10000:
                text = text[:10000] + "\n\n[Content truncated due to length]"
                
            return text if text else "Could not extract text from this page."
            
        except Exception as e:
            return f"Error reading webpage: {str(e)}"

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=["search", "read"], required=True)
    parser.add_argument("--query", type=str, help="Search query")
    parser.add_argument("--page", type=int, default=1, help="Page number (1-indexed)")
    parser.add_argument("--url", type=str, help="URL to read")
    
    args = parser.parse_args()
    
    if args.mode == "search":
        if not args.query:
            print("Error: --query is required for search mode")
            sys.exit(1)
        print(search_web(args.query, args.page))
    elif args.mode == "read":
        if not args.url:
            print("Error: --url is required for read mode")
            sys.exit(1)
        print(read_webpage(args.url))
