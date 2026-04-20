import urllib.request
import urllib.error

url = "http://localhost:5000/api/health"

try:
    response = urllib.request.urlopen(url, timeout=5)
    print(response.read().decode())
except urllib.error.HTTPError as e:
    print(f"HTTP Error: {e.code} - {e.reason}")
except urllib.error.URLError as e:
    print(f"URL Error: {e.reason}")
except Exception as e:
    print(f"Error: {e}")
