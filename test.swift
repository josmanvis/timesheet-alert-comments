import Foundation

let path = "/tmp/fake"
let appleScriptSource = """
do shell script "mkdir -p /usr/local/bin && mv \"\(path)\" /usr/local/bin/tac && chmod +x /usr/local/bin/tac" with administrator privileges
"""
print(appleScriptSource)
