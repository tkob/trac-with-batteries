import os

os.environ['TRAC_ENV_PARENT_DIR'] = '{{trac_parent}}'
os.environ['PYTHON_EGG_CACHE'] = '{{egg_cache}}'

import trac.web.main
application = trac.web.main.dispatch_request
