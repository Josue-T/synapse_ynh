import json

with open("/etc/ssowat/conf.json.persistent", "r", encoding='utf-8') as jsonFile:
    data = json.load(jsonFile)
    if "skipped_urls" in data and "/_matrix" not in data:
        data["skipped_urls"].append("/_matrix")
    else:
        data["skipped_urls"] = ["/_matrix"]
    if "protected_urls" in data and "/_matrix/cas_server.php/login" not in data:
        data["protected_urls"].append("/_matrix/cas_server.php/login")
    else:
        data["protected_urls"] = ["/_matrix/cas_server.php/login"]

with open("/etc/ssowat/conf.json.persistent", "w", encoding='utf-8') as jsonFile:
    jsonFile.write(json.dumps(data, indent=4, sort_keys=True))
