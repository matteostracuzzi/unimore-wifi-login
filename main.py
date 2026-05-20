#!/usr/bin/env python3
import requests
import re
import sys
import json
import logging


logger = logging.getLogger(__name__)

with open("/etc/unimore-login/credentials.json","r") as f:
    data = json.load(f)

CHECK_URL = "http://detectportal.firefox.com/sucess.txt" 

PAYLOAD = {
    "user": data["username"],
    "password": data["password"],
    "cmd": "authenticate"            # Campo nascosto (hidden) fondamentale richiesto dal portale
}


def do_aruba_login():
    session = requests.Session()
    session.headers.update({
        "User-Agent": "Mozilla/5.0 (X11; Arch Linux; Linux x86_64; rv:120.0) Gecko/20100101 Firefox/120.0"
    })

    try:
        print(f"Tentativo di connessione a {CHECK_URL}...")
        response = session.get(CHECK_URL, timeout=10)
        if response.text == "success":
            logging.warn("already connected to the internet")
            return

        # Cerchiamo l'URL dentro il tag meta refresh usando una Regular Expression
        match = re.search(r"url=([^'\"]+)['\"]", response.text, re.IGNORECASE)

        if not match:
            logging.error("HTML non riconosciuto. Impossibile trovare l'URL del portale.")
            sys.exit(1)

        # Estraiamo l'URL dinamico
        captive_url = match.group(1)
        logging.debug(f"Portale Aruba rilevato! URL di reindirizzamento: {captive_url}")

        # Facciamo una GET verso questo nuovo URL. 
        # I sistemi Aruba di solito ti reindirizzano ancora una volta verso la pagina di login REALE (quella col form)
        login_page_response = session.get(captive_url, timeout=10, allow_redirects=True)
        
        # L'URL finale dove inviare la POST con le credenziali
        real_post_url = login_page_response.url
        logging.debug(f"final url: {real_post_url}")
        # Inviamo finalmente i dati di login
        logging.debug("sending credentials")
        login_response = session.post(real_post_url, data=PAYLOAD, timeout=10)

        if not "access denied" in login_response.text:
            logging.info("Logged succesfull")
        else:
            logging.error("Access denied")

    except requests.exceptions.RequestException as e:
        logger.error(f"Network Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    logger.info('Started')
    do_aruba_login()

