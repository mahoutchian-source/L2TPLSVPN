import sys
from playwright.sync_api import sync_playwright
with sync_playwright() as p:
    b = p.chromium.launch()
    for theme in ("dark", "light"):
        pg = b.new_page(viewport={"width": 1400, "height": 900})
        pg.add_init_script("try{localStorage.setItem('theme','%s')}catch(e){}" % theme)
        pg.goto("http://127.0.0.1:18082/")
        pg.fill("input[name=password]", "testpass123"); pg.keyboard.press("Enter"); pg.wait_for_timeout(800)
        pg.goto("http://127.0.0.1:18082/"); pg.wait_for_timeout(11000)
        pg.screenshot(path="dash-%s.png" % theme, full_page=True)
        pg.goto("http://127.0.0.1:18082/sites"); pg.wait_for_timeout(11000)
        pg.screenshot(path="sites-%s.png" % theme, full_page=True)
    b.close()
