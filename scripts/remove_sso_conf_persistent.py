import json
import sys

with open("/etc/ssowat/conf.json.persistent", "r", encoding='utf-8') as jsonFile:
    data = json.load(jsonFile)

    for domain in ("", sys.argv[1], sys.argv[2]):
        for path in ("/_matrix", "/.well-known/matrix/", "/_matrix/cas_server.php/login"):
            url = domain + path
            try:
                uri_list = data["skipped_urls"]
                while url in uri_list:
                    uri_list.remove(url)     
            except:
                pass

            try:
                uri_list = data["protected_urls"]
                while url in uri_list:
                    uri_list.remove(url)     
            except:
                pass

            try:
                uri_list = data["permissions"]["custom_protected"]["uris"]
                while url in uri_list:
                    uri_list.remove(url)     
            except:
                pass

            try:
                uri_list = data["permissions"]["custom_skipped"]["uris"]
                while url in uri_list:
                    uri_list.remove(url)     
            except:
                pass

with open("/etc/ssowat/conf.json.persistent", "w", encoding='utf-8') as jsonFile:
    jsonFile.write(json.dumps(data, indent=4, sort_keys=True))
