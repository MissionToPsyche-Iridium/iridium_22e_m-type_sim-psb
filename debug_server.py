"""

!!!THIS FILE IS NOT USED IN PRODUCTION!!!

This is a simple HTTP server that serves the current directory with appropriate CORS headers.

You can use it to verify that the project works, but this should be hosted on a proper static HTML host.

"""

import http.server
import socketserver
import os

PORT = 8000
DIRECTORY = "." # Serve the current directory

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

    def end_headers(self):
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')
        http.server.SimpleHTTPRequestHandler.end_headers(self)

# Ensure the server uses IPv4 and allows address reuse
socketserver.TCPServer.allow_reuse_address = True
with socketserver.TCPServer(("", PORT), Handler) as httpd:
    httpd.allow_reuse_address = True # Allow address reuse for quick restarts
    print(f"Serving directory '{os.path.abspath(DIRECTORY)}' at http://localhost:{PORT}")
    print("Adding headers:")
    print("  Cross-Origin-Opener-Policy: same-origin")
    print("  Cross-Origin-Embedder-Policy: require-corp")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nServer stopped.")
        httpd.server_close()
