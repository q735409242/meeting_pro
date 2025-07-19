import requests
url = "https://rtc.live.cloudflare.com/v1/turn/keys/7fa7ceaf02944aff9226ab0fcaad0555/credentials/generate"
headers = {
    "Authorization": "Bearer 51cc161512bf5590d02a6977cc19f880ac140ab22ccd44e15381397cc330c3b5",
    "Content-Type": "application/json",
}
data = {"ttl": 86400}
# print("获取turn服务器信息")
try:
    response = requests.post(url, headers=headers, json=data)
    if response.status_code == 201:
        print("获取turn服务器信息成功", response.json())
except Exception:
    print("获取turn服务器信息失败")
