#!/usr/bin/env python3

import base64
import hashlib
import os
import requests
import sqlite3
import unicodedata
import urllib.parse

# Finding the database file, kudos to https://github.com/andymatuschak/Bear-Markdown-Export


HOME = os.getenv('HOME', '')
URL=os.getenv("CMSBEAR_URL") or "https://joitestwww.eu.ngrok.io"
API_KEY=os.getenv("CMSBEAR_API_KEY") or "h41RLrP90NsOZT0YQe5qWCCMWnUqL6AbYeBRW7RkBe1ErmhC5bwXuhCpGPO1yvtNMKotcYM4Anw7pxaE37paBkpbC6uLUee0TpH"

def content_hash(full_path):
  ch = hashlib.sha1()
  with open(full_path, 'rb') as f:
    while True:
        buf = f.read(67_108_864)
        if not buf:
          break
        ch.update(buf)
  # Transform the digests into strings matching format of what we receive from the server
  return base64.b32encode(ch.digest()).lower().decode('utf-8')

def path_hash(rel_path):
  #return unicodedata.normalize('NFD', rel_path.decode('utf-8'))
  # Transform the digests into strings matching format of what we receive from the server
  rel_path = unicodedata.normalize('NFC', rel_path).encode(encoding='UTF-8')
  return base64.b32encode(hashlib.sha1(rel_path).digest()).lower().decode('utf-8')

def paths_and_hashes(root_path):
  paths = []
  for root, dir, files in os.walk(root_path):
    for filename in files:
      full_path = os.path.abspath(os.path.join(root, filename))
      rel_path = full_path[len(root_path)+1:]
      if rel_path.count("/") == 1:
        ph = path_hash(rel_path)
        ch = content_hash(full_path)
        paths.append(
          (rel_path, full_path, ph, ch)
        )
  return paths

def upload_missing_assets(p_and_h, hashes, type):
  for (rel_path, full_path, path_hash, content_hash) in p_and_h:
    if not path_hash in hashes or hashes[path_hash] != content_hash:
      (guid, filename) = rel_path.split("/")
      url = URL + "/api/up/" + urllib.parse.quote(type) + "/" + urllib.parse.quote(guid) + "/" + urllib.parse.quote(filename)
      #print(url)
      r = requests.post(url, headers={'Authorization': 'Basic ' + API_KEY}, files={'upload': open(full_path, 'rb')})
      print("Uploading missing or changed asset %s (ph: %s, ch: %s" % (rel_path, path_hash, content_hash))
      print("Result is %d" % r.status_code)

def get_hashes_from_server():
  r = requests.get(URL + "/api/hashes", headers={'Authorization': 'Basic ' + API_KEY})
  print('Hashes request result is %d' % r.status_code)
  return r.json()


def main():
  print("URL is %s" % URL)
  print("API key is %s" % API_KEY)

  bear_db = os.path.join(HOME, 'Library/Group Containers/9K33E3U3T4.net.shinyfrog.bear/Application Data/database.sqlite')
  img_root = os.path.abspath(os.path.join(HOME, 'Library/Group Containers/9K33E3U3T4.net.shinyfrog.bear/Application Data/Local Files/Note Images'))
  file_root = os.path.abspath(os.path.join(HOME, 'Library/Group Containers/9K33E3U3T4.net.shinyfrog.bear/Application Data/Local Files/Note Files'))

  hashes = get_hashes_from_server()

  # Get a clean DB snapshot
  try:
    os.remove("/tmp/bear.sqlite")
  except:
    pass
  con = sqlite3.connect(bear_db)
  cur = con.cursor()
  cur.execute("VACUUM INTO '/tmp/bear.sqlite'")
  con.commit()
  con.close()

  db_hash = content_hash("/tmp/bear.sqlite")

  if (db_hash != hashes['db']):
    # Upload the new DB file
    r = requests.post(URL + "/api/up/db", headers={'Authorization': 'Basic ' + API_KEY}, files={'upload': open('/tmp/bear.sqlite', 'rb')})
    print('DB upload result is %d' % r.status_code)
  else:
    print('DB is unchanged, not uploading')

  files = paths_and_hashes(file_root)
  images = paths_and_hashes(img_root)

  upload_missing_assets(files, hashes['files'], 'file')
  upload_missing_assets(images, hashes['images'], 'image')

  print("CMSBear upload done!")


if __name__ == '__main__':
  main()

