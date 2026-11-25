import sys
from playwright.sync_api import sync_playwright
B="http://127.0.0.1:18084"
with sync_playwright() as p:
    b=p.chromium.launch(executable_path="/opt/pw-browsers/chromium")
    pg=b.new_page(viewport={"width":1100,"height":900})
    pg.goto(B+"/login"); pg.fill("input[name=password]","pw123456"); pg.click("button")
    pg.wait_for_timeout(800)
    pg.screenshot(path="s-main.png")
    pg.goto(B+"/edit?name=only"); pg.wait_for_timeout(500)
    pg.locator("fieldset", has_text="If IPsec is missing").scroll_into_view_if_needed()
    pg.screenshot(path="s-edit.png", full_page=False)
    b.close()
