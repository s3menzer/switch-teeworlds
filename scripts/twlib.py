import sys
if sys.version_info[0] == 2:
	import urllib
	url_lib = urllib
elif sys.version_info[0] == 3:
	import urllib.request
	url_lib = urllib.request

def fetch_file(url):
	print("trying %s" % url)
	try:
		# GitHub archive responses do not always include a
		# Content-Disposition header. Use a deterministic local filename
		# instead of treating that valid response as a failed download.
		local = "teeworlds-libs-download.zip"
		url_lib.urlretrieve(url, local)
		return local
	except (IOError, OSError):
		return False
