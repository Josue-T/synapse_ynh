import json

server_name = sys.argv[1]
domain = sys.argv[2]

with open("/etc/ssowat/conf.json.persistent", "r", encoding='utf-8') as jsonFile:
    data = json.load(jsonFile)

    # Remove entry without the domain specified
    data["skipped_urls"].remove("/_matrix")

    if "skipped_urls" in data and "/_matrix" not in data:
        data["skipped_urls"] += [domain + "/_matrix", server_name + "/.well-known/matrix/"]
    else:
        data["skipped_urls"] = [domain + "/_matrix", server_name + "/.well-known/matrix/"]
    if "protected_urls" in data and domain +  "/_matrix/cas_server.php/login" not in data:
        data["protected_urls"].append(domain + "/_matrix/cas_server.php/login")
    else:
        data["protected_urls"] = [domain + "/_matrix/cas_server.php/login"]

with open("/etc/ssowat/conf.json.persistent", "w", encoding='utf-8') as jsonFile:
    jsonFile.write(json.dumps(data, indent=4, sort_keys=True))
