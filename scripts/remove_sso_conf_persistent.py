import json
import sys

domain = sys.argv[1]
server_name = sys.argv[2]

with open("/etc/ssowat/conf.json.persistent", "r", encoding='utf-8') as jsonFile:
    data = json.load(jsonFile)

    for domain in ("", sys.argv[1], sys.argv[2]):
        for path in ("/_matrix", "/.well-known/matrix/", "/_matrix/cas_server.php/login"):
            for l in (data["skipped_urls"],
                      data["protected_urls"],
                      data["permissions"]["custom_protected"]["uris"],
                      data["permissions"]["custom_skipped"]["uris"]):
            url = domain + path
            while url in l:
                l.remove(url)

with open("/etc/ssowat/conf.json.persistent", "w", encoding='utf-8') as jsonFile:
    jsonFile.write(json.dumps(data, indent=4, sort_keys=True))
