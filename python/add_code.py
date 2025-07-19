import requests
url='https://yuliao.yunkefu.pro/add_reg_code/'
data={
	"expiration_time": "2025/04/29 00:00",
	"agent": "测试",
	"quantity": 10,
	"text":"2"
}
headers={
    "Content-Type": "application/json"}

response = requests.post(url, json=data)
# print(response.json())
for code in response.json()['users_info']:
    print(code['registration_code'])
