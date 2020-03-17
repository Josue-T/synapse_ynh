import json

with open("/etc/ssowat/conf.json.persistent", "r", encoding='utf-8') as jsonFile:
    data = json.load(jsonFile)

    for entry in data["skipped_urls"].copy():
        if "/_matrix" in entry or "/.well-known/matrix/" in entry:
            data["skipped_urls"].remove(entry)

    for entry in data["protected_urls"].copy():
        if "/_matrix" in entry:
            data["protected_urls"].remove(entry)

with open("/etc/ssowat/conf.json.persistent", "w", encoding='utf-8') as jsonFile:
    jsonFile.write(json.dumps(data, indent=4, sort_keys=True))
