import json
import sys

domain = sys.argv[1]
server_name = sys.argv[2]

with open("/etc/ssowat/conf.json.persistent", "r", encoding='utf-8') as jsonFile:
    data = json.load(jsonFile)

    if "skipped_urls" not in data:
        data["skipped_urls"] = []
    if "protected_urls" not in data:
        data["protected_urls"] = []

    # Remove entry without the domain specified
    if "/_matrix" in data["skipped_urls"]:
        data["skipped_urls"].remove("/_matrix")

    if domain + "/_matrix" not in data["skipped_urls"]:
        data["skipped_urls"].append(domain + "/_matrix")
    if server_name + "/.well-known/matrix/" not in data["skipped_urls"]:
        data["skipped_urls"].append(server_name + "/.well-known/matrix/")

    if domain +  "/_matrix/cas_server.php/login" not in data["protected_urls"]:
        data["protected_urls"].append(domain + "/_matrix/cas_server.php/login")

with open("/etc/ssowat/conf.json.persistent", "w", encoding='utf-8') as jsonFile:
    jsonFile.write(json.dumps(data, indent=4, sort_keys=True))
