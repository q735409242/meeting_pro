import requests
import time

# 声网配置
app_id = "2eb90a7123d14279883ddcffb1b75b10"
app_certificate = "fe78668afa2f4f43935bd047bc5e99f0"
channel_name = "4776"
uid = "0"  # 字符串格式，如果是 int uid 就写数字
expire = 86400  # token 有效期，单位秒

# 构造请求体
url = "https://toolbox.bj2.agoralab.co/v1/token/generate"
payload = {
    "appId": app_id,
    "appCertificate": app_certificate,
    "channelName": channel_name,
    "expire": expire,
    "src": "Android",
    "ts": int(time.time() * 1000),  # 毫秒时间戳
    "type": 1,  # 1 = uid token
    "uid": uid
}

# 发送 POST 请求
response = requests.post(url, json=payload)

# 解析响应
if response.status_code == 200:
    token = response.json().get("data", "")
    print("✅ 成功获取 Token:")
    print(token)
else:
    print("❌ 请求失败:", response.status_code)
    print(response.text)