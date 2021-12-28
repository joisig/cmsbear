#!/usr/bin/env python3

import base64
import hashlib
import os
import requests
import sqlite3

HOME = os.getenv('HOME', '')
URL=os.getenv("CMSBEAR_URL") or "https://joitestwww.eu.ngrok.io"
API_KEY=os.getenv("CMSBEAR_API_KEY") or "h41RLrP90NsOZT0YQe5qWCCMWnUqL6AbYeBRW7RkBe1ErmhC5bwXuhCpGPO1yvtNMKotcYM4Anw7pxaE37paBkpbC6uLUee0TpH"

print("URL is %s" % URL)
print("API key is %s" % API_KEY)

bear_db = os.path.join(HOME, 'Library/Group Containers/9K33E3U3T4.net.shinyfrog.bear/Application Data/database.sqlite')
img_root = os.path.abspath(os.path.join(HOME, 'Library/Group Containers/9K33E3U3T4.net.shinyfrog.bear/Application Data/Local Files/Note Images'))
file_root = os.path.abspath(os.path.join(HOME, 'Library/Group Containers/9K33E3U3T4.net.shinyfrog.bear/Application Data/Local Files/Note Files'))

# Get a clean DB snapshot
os.remove("/tmp/bear.sqlite")
con = sqlite3.connect(bear_db)
cur = con.cursor()
cur.execute("VACUUM INTO '/tmp/bear.sqlite'")
con.commit()
con.close()

# Upload the new DB file
#r = requests.post(URL + "/api/up/db", headers={'Authorization': 'Basic ' + API_KEY}, files={'upload': open('/tmp/bear.sqlite', 'rb')})
#print('DB upload result is %d' % r.status_code)

def paths_and_hashes(root_path):
  paths = []
  for root, dir, files in os.walk(root_path):
    for filename in files:
      full_path = os.path.abspath(os.path.join(root, filename))
      rel_path = full_path[len(root_path)+1:]
      ph = hashlib.sha1(rel_path.encode(encoding='UTF-8'))
      ch = hashlib.sha1()
      with open(full_path, 'rb') as f:
        while True:
            buf = f.read(67_108_864)
            if not buf:
              break
            ch.update(buf)
      paths.append((rel_path, full_path, base64.b32encode(ph.digest()).lower().decode('utf-8'), base64.b32encode(ch.digest()).lower().decode('utf-8')))
  return paths

files = paths_and_hashes(file_root)
images = paths_and_hashes(img_root)

print(files[0])

r = requests.get(URL + "/api/hashes", headers={'Authorization': 'Basic ' + API_KEY})
print('Hashes request result is %d' % r.status_code)
hashes = r.json()
print(hashes['files'][0])