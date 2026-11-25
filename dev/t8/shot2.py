from playwright.sync_api import sync_playwright
B='http://127.0.0.1:18082'
with sync_playwright() as p:
    b=p.chromium.launch(executable_path='/opt/pw-browsers/chromium',args=['--no-sandbox'])
    pg=b.new_context(viewport={'width':1100,'height':760}).new_page()
    pg.goto(B+'/'); pg.fill('#pw','pw123456'); pg.click('button'); pg.wait_for_selector('.row')
    pg.screenshot(path='w-main.png')
    for n,u in (('check','/check'),('backup','/backup'),('settings','/settings'),('logs','/logs?name=a')):
        pg.goto(B+u); pg.screenshot(path=f'w-{n}.png',full_page=True)
    b.close()
