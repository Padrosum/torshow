#!/usr/bin/env python3
"""Read the active Tor circuit through the local authenticated control port."""
import json
import os
import socket
import sys

try:
    import pycountry
except ImportError:
    pycountry = None

try:
    from stem import Signal
    from stem.control import Controller

    controller = Controller.from_port(address="127.0.0.1", port=9051)
    controller.authenticate()
    bootstrap = controller.get_info("status/bootstrap-phase", "").split(" PROGRESS=")[-1].split(" ")[0]
    circuits = [c for c in controller.get_circuits() if c.status == "BUILT" and len(c.path) >= 3]
    result = {"ok": True, "bootstrap": "Ağa bağlandı · " + bootstrap + "%"}

    if circuits:
        # Prefer a general-purpose circuit. Tor paths expose relay identities;
        # the directory cache provides their addresses and Tor's own GeoIP DB
        # supplies the corresponding country code.
        circuit = next((c for c in circuits if c.purpose == "GENERAL"), circuits[0])
        slots = ("entry", "middle", "exit")
        for slot, (fingerprint, nickname) in zip(slots, circuit.path[:3]):
            relay = controller.get_network_status(fingerprint, None)
            country = "??"
            if relay:
                country = controller.get_info("ip-to-country/" + relay.address, "??").upper()
            flag = "".join(chr(0x1F1E6 + ord(c) - ord("A")) for c in country) if len(country) == 2 and country.isalpha() else "🌐"
            country_name = country
            if pycountry and len(country) == 2:
                country_name = getattr(pycountry.countries.get(alpha_2=country), "name", country)
            result[slot] = {"country": country_name, "code": country, "flag": flag, "relay": nickname or fingerprint[:8]}
    else:
        result["ok"] = False
        result["error"] = "Henüz kurulmuş Tor devresi yok"

    controller.close()
    print(json.dumps(result, ensure_ascii=False))
except Exception as exc:
    print(json.dumps({"ok": False, "error": str(exc)[:120]}, ensure_ascii=False))
