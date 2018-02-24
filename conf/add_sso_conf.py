import json

with open("/etc/ssowat/conf.json.persistent", "r", encoding='utf-8') as jsonFile:
    data = json.load(jsonFile)
    if "skipped_urls" in data:
        data["skipped_urls"].append("/_matrix")
    else:
        data["skipped_urls"] = ["/_matrix"]

with open("/etc/ssowat/conf.json.persistent", "w", encoding='utf-8') as jsonFile:
    jsonFile.write(json.dumps(data, indent=4, sort_keys=True))