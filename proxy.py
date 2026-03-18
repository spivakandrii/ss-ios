#!/usr/bin/env python3
"""Simple HTTP proxy for Sabbath School API.
iPad (iOS 5.1.1) can't do TLS 1.2, so this proxy
listens on HTTP and forwards to HTTPS API.

Usage: python3 proxy.py
Then set iPad app to use http://<your-pc-ip>:8080
"""

import json
import sys

try:
    from http.server import HTTPServer, BaseHTTPRequestHandler
    import urllib.request
    import ssl
except ImportError:
    print("Python 3 required")
    sys.exit(1)

API_BASE = "https://sabbath-school.adventech.io"
PORT = 8080

class ProxyHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        url = API_BASE + self.path
        try:
            ctx = ssl.create_default_context()
            req = urllib.request.Request(url)
            req.add_header('User-Agent', 'SabbathSchool/1.0')
            resp = urllib.request.urlopen(req, context=ctx, timeout=30)
            data = resp.read()

            self.send_response(200)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('Content-Length', str(len(data)))
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(data)
        except Exception as e:
            err = json.dumps({"error": str(e)}).encode('utf-8')
            self.send_response(502)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(err)))
            self.end_headers()
            self.wfile.write(err)

    def log_message(self, format, *args):
        print(f"[PROXY] {args[0]}")

if __name__ == '__main__':
    import socket
    hostname = socket.gethostname()
    local_ip = socket.gethostbyname(hostname)
    print(f"=== Sabbath School API Proxy ===")
    print(f"Listening on http://0.0.0.0:{PORT}")
    print(f"Your PC IP: {local_ip}")
    print(f"Set app API base to: http://{local_ip}:{PORT}/api/v2/uk")
    print(f"Press Ctrl+C to stop\n")

    server = HTTPServer(('0.0.0.0', PORT), ProxyHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopped.")
