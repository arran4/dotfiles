import urllib.request
import json
import sys

def search(q):
    url = f"https://api.github.com/search/issues?q={q}"
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req) as response:
        return json.loads(response.read().decode())

print("search...")
res = search("org:community+ghcr+readme")
for item in res.get("items", []):
    print(item["title"])
