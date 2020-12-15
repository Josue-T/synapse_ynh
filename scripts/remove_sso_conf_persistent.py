import json
import sys

domain = sys.argv[1]
server_name = sys.argv[2]

with open("/etc/ssowat/conf.json.persistent", "r", encoding='utf-8') as jsonFile:
    data = json.load(jsonFile)

    data["skipped_urls"].remove("/_matrix")
    data["skipped_urls"].remove("/.well-known/matrix/")
    data["protected_urls"].remove("/_matrix/cas_server.php/login")

with open("/etc/ssowat/conf.json.persistent", "w", encoding='utf-8') as jsonFile:
    jsonFile.write(json.dumps(data, indent=4, sort_keys=True))
