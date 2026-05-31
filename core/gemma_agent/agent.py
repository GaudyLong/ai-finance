import json
import re
from datetime import datetime, timedelta
import httpx
from core.gemma_agent.prompts import SYSTEM_PARSER_PROMPT, SYSTEM_ADVISOR_PROMPT, PARSER_USER_TEMPLATE

OLLAMA_HOST = "http://localhost:11434"
MODEL_NAME = "gemma:2b"

class GemmaAgent:
    def __init__(self, host: str = OLLAMA_HOST, model: str = MODEL_NAME):
        self.host = host
        self.model = model
        self.client = httpx.Client(timeout=10.0)

    def is_ollama_available(self) -> bool:
        """Check if Ollama server is running locally."""
        try:
            resp = self.client.get(f"{self.host}/api/tags")
            return resp.status_code == 200
        except Exception:
            return False

    def parse_transaction(self, text: str) -> dict:
        """
        Parses raw input text to extract a structured transaction using Gemma 2B.
        If Ollama is offline or fails, falls back to a smart local parser.
        """
        today_str = datetime.now().strftime("%Y-%m-%d")
        prompt = SYSTEM_PARSER_PROMPT.format(today=today_str)
        user_prompt = PARSER_USER_TEMPLATE.format(text=text)

        if self.is_ollama_available():
            try:
                # Ask Gemma:2b via Ollama
                payload = {
                    "model": self.model,
                    "prompt": f"{prompt}\n\n{user_prompt}",
                    "stream": False,
                    "options": {
                        "temperature": 0.1
                    }
                }
                resp = self.client.post(f"{self.host}/api/generate", json=payload)
                if resp.status_code == 200:
                    result = resp.json().get("response", "").strip()
                    # Clean potential markdown wrappers
                    result = re.sub(r"^```json\s*", "", result)
                    result = re.sub(r"\s*```$", "", result)
                    
                    data = json.loads(result)
                    # Validate keys
                    if "amount" in data and "type" in data:
                        return {
                            "amount": float(data.get("amount", 0)),
                            "type": data.get("type", "expense"),
                            "category": data.get("category", "Other"),
                            "description": data.get("description", text[:30]),
                            "payment_method": data.get("payment_method", "Other"),
                            "date": data.get("date", today_str),
                            "raw_text": text
                        }
            except Exception as e:
                print(f"Ollama parsing failed: {e}. Switching to fallback parser.")

        # Fallback to local regex-based parser
        return self._local_fallback_parse(text)

    def chat_with_advisor(self, message: str, history: list = None) -> tuple:
        """
        Generates advisor reply. Also returns a parsed transaction dict if bookkeeping intent is detected.
        """
        if history is None:
            history = []

        # 1. Detect if the user wants to log a transaction in their message.
        # Check if message contains numbers (likely an amount) and bookkeeping key terms
        has_numbers = any(char.isdigit() for char in message)
        bookkeep_keywords = ["花", "买", "付", "收", "赚", "支", "用", "费", "充", "元", "块", "存", "微信", "支付宝", "现金", "刷卡"]
        is_bookkeeping_intent = has_numbers and any(kw in message for kw in bookkeep_keywords)
        
        parsed_txn = None
        if is_bookkeeping_intent:
            parsed_txn = self.parse_transaction(message)
            # If parsed amount is 0, we treat it as failed extraction
            if parsed_txn and parsed_txn.get("amount", 0) <= 0:
                parsed_txn = None

        # 2. Get advisor conversation response
        reply = ""
        if self.is_ollama_available():
            try:
                # Structure prompt for Ollama chat endpoint
                messages = [{"role": "system", "content": SYSTEM_ADVISOR_PROMPT}]
                for h in history:
                    messages.append(h)
                messages.append({"role": "user", "content": message})

                payload = {
                    "model": self.model,
                    "messages": messages,
                    "stream": False
                }
                resp = self.client.post(f"{self.host}/api/chat", json=payload)
                if resp.status_code == 200:
                    reply = resp.json().get("message", {}).get("content", "").strip()
            except Exception as e:
                print(f"Ollama chat failed: {e}. Switching to local AI response.")

        if not reply:
            reply = self._get_local_advisor_reply(message, parsed_txn)

        return reply, parsed_txn

    def _local_fallback_parse(self, text: str) -> dict:
        """
        Smart offline regex parser for bookkeeping sentences.
        Example: "昨天吃午饭花了50块微信支付的" ->
        { amount: 50.0, type: 'expense', category: 'Food', description: '吃午饭', payment_method: 'WeChat Pay', date: '2026-05-30' }
        """
        today = datetime.now()
        date_str = today.strftime("%Y-%m-%d")

        # 1. Date Detection
        if "昨天" in text:
            date_str = (today - timedelta(days=1)).strftime("%Y-%m-%d")
        elif "前天" in text:
            date_str = (today - timedelta(days=2)).strftime("%Y-%m-%d")
        elif "明天" in text:
            date_str = (today + timedelta(days=1)).strftime("%Y-%m-%d")

        # 2. Amount Detection (Find numbers, supporting decimals)
        amount = 0.0
        # Look for numbers matching floats or integers
        numbers = re.findall(r"\d+(?:\.\d+)?", text)
        if numbers:
            # Usually the first number in bookkeeping is the amount
            amount = float(numbers[0])

        # 3. Type Detection
        txn_type = "expense"
        if any(kw in text for kw in ["工资", "收", "赚", "发钱", "兼职", "红包"]):
            txn_type = "income"

        # 4. Category Detection
        category = "Other"
        category_map = {
            "Food": ["吃", "饭", "外卖", "大餐", "麻辣烫", "火锅", "零食", "饮品", "咖啡", "水果", "早餐", "午餐", "晚餐"],
            "Transport": ["车", "地铁", "打车", "公交", "机票", "高铁", "火车", "加油", "汽油", "滴滴", "共享单车"],
            "Shopping": ["买", "衣服", "鞋子", "包包", "淘宝", "京东", "拼多多", "日用", "超市", "网购", "电子产品"],
            "Salary": ["工资", "奖金", "发薪", "兼职", "劳务费"],
            "Entertainment": ["电影", "游戏", "充值", "网吧", "桌游", "酒吧", "ktv", "旅游", "门票"],
            "Utilities": ["房租", "水电", "水费", "电费", "物业", "宽带", "话费", "燃气"],
            "Medical": ["药", "医院", "挂号", "感冒", "看病", "体检"],
            "Education": ["书", "课", "培训", "学费", "文具", "报班"]
        }
        for cat, keywords in category_map.items():
            if any(kw in text for kw in keywords):
                category = cat
                break

        # 5. Payment Method Detection
        payment_method = "Other"
        if "微信" in text:
            payment_method = "WeChat Pay"
        elif "支付宝" in text:
            payment_method = "Alipay"
        elif any(kw in text for kw in ["刷卡", "信用卡", "银行卡", "银联"]):
            payment_method = "Credit Card"
        elif "现金" in text:
            payment_method = "Cash"

        # 6. Description Creation
        description = text
        # Remove numbers and helper words to clean description
        clean_desc = re.sub(r"\d+(?:\.\d+)?", "", text)
        for w in ["元", "块", "钱", "微信", "支付宝", "付", "花了", "支出", "收入", "昨天", "今天", "前天"]:
            clean_desc = clean_desc.replace(w, "")
        clean_desc = clean_desc.strip(",.，。!！ ")
        if clean_desc:
            description = clean_desc[:20]
        else:
            description = "账目记录" if txn_type == "expense" else "收入记录"

        return {
            "amount": amount,
            "type": txn_type,
            "category": category,
            "description": description,
            "payment_method": payment_method,
            "date": date_str,
            "raw_text": text
        }

    def _get_local_advisor_reply(self, message: str, parsed_txn: dict) -> str:
        """Fallback local response system if Gemma (Ollama) is offline."""
        if parsed_txn:
            amount = parsed_txn['amount']
            category_cn = {
                "Food": "餐饮", "Transport": "交通", "Shopping": "购物",
                "Salary": "工资", "Entertainment": "娱乐", "Utilities": "水电房租",
                "Medical": "医疗", "Education": "教育", "Other": "其他"
            }.get(parsed_txn['category'], "其他")
            
            type_cn = "支出" if parsed_txn['type'] == 'expense' else "收入"
            pay_cn = {
                "WeChat Pay": "微信支付", "Alipay": "支付宝",
                "Credit Card": "信用卡", "Cash": "现金", "Other": "其他"
            }.get(parsed_txn['payment_method'], "未指定方式")

            if parsed_txn['type'] == 'expense':
                advice = "记下来啦！适当控制支出，合理规划消费哦。"
                if amount > 100:
                    advice = f"金额达到了 {amount} 元，属于一笔较大的支出，要留意这笔消费是否为非必需品哦！"
                elif parsed_txn['category'] == 'Shopping':
                    advice = "购物消费记账成功。买买买确实开心，但也记得货比三家哈。"
            else:
                advice = "太棒了，又有一笔资金入账！继续加油，存下更多小金库！"

            return f"🤖 **记账助手已识别**：\n已成功从您的信息中解析到一笔 {category_cn} {type_cn}，金额为 **{amount} 元**（通过 {pay_cn}）。\n\n{advice}\n*(注：当前运行在本地离线解析引擎)*"
        
        # General chat replies
        msg_lower = message.lower()
        if "你好" in msg_lower or "hello" in msg_lower:
            return "你好！我是你的 AI 财务管家。你可以直接对我说：\n*“今天吃午饭花了35元，微信付的”*\n或者问我：\n*“如何做好每月的预算规划？”*"
        elif "预算" in msg_lower:
            return "规划预算推荐采用 **50/30/20法则**：\n- **50% 必要支出**：房租、餐食、日常水电、通勤交通。\n- **30% 想要支出**：聚会娱乐、买衣服、兴趣爱好等灵活开销。\n- **20% 储蓄/投资**：用于紧急预备金或长期理财。\n\n你可以通过右下角的“明细”来随时查看当月进度！"
        elif "存钱" in msg_lower or "理财" in msg_lower:
            return "给你分享几个极简存钱技巧：\n1. **先存后花**：发工资当天先把 20% 转入定期或理财账户。\n2. **记账反思**：每周日花 5 分钟查看我的账单统计，找出不必要的开销。\n3. **强制冷却**：把想买的东西加购物车，冷却 48 小时再决定是否买。\n\n需要我帮你分析上周的账单吗？"
        
        return "收到！我是你的智能账单小管家。你可以随时向我咨询理财知识，或者直接发一句话记账。例如：“打车花了18元” 🚗"
