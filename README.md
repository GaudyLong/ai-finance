# AI Finance 🪙

AI Finance 是一款基于 **Gemma 2B** 大语言模型的智能记账与理财助手移动端系统。该项目拥有原生 **iOS (SwiftUI)** 前端客户端与 **FastAPI (Python)** 后端，实现全自动的自然语言记账解析、个性化理财咨询和丰富的财务看板统计。

---

## 🌟 核心特性

- **💬 AI 智能对话记账**：发送一句话（例如：“昨晚吃麻辣烫微信支付了35元”），Gemma 模型将自动识别金额、收支分类、支付方式及日期，生成结构化记账单，用户一键确认即可快速入账。
- **📊 动态财务看板 (SwiftUI Charts)**：支持以图表形式展示最近 7 日的收支走势，并对餐饮、出行、购物等消费大类进行占比分析与进度条百分比展示。
- **🤖 专属理财顾问**：内置基于 Gemma 2B 大模型的智能财务顾问 “AI 小财”，可为用户提供量身定制的理财小贴士、预算规划方案（如 50/30/20 法则）和存钱技巧。
- **🛡️ 强大的离线降级方案**：当大模型连接超时或离线时，系统会自动无缝降级为**本地正则表达式与规则解析器**，保证记账服务 100% 可靠可用。
- **📱 现代 iOS 设计风格**：基于 SwiftUI 原生开发，支持暗黑模式，采用精美渐变、微动效卡片、圆角玻璃态以及顺畅的侧滑删除等交互设计。

---

## 🏗️ 系统架构

```mermaid
graph TD
    subgraph iOS 客户端 (SwiftUI)
        A[DashboardView 看板] -->|数据读取| NM[NetworkManager]
        B[ChatView AI记账] -->|语音/文字输入| NM
        C[TransactionListView 明细] -->|手势删除/过滤| NM
        D[AddTransactionView 手动] -->|直接写入| NM
    end

    subgraph 后端服务 (FastAPI)
        NM -->|HTTP API 请求| FA[FastAPI App]
        FA -->|数据持久化| DB[(SQLite 数据库)]
        FA -->|调用 Agent| GA[GemmaAgent]
    end

    subgraph 大模型层 (Local LLM)
        GA -->|Ollama API| OM[Gemma:2b 模型]
        GA -.->|离线状态下自动切换| FB[正则规则解析引擎]
    end
```

---

## 🚀 快速开始

### 1. 模型准备 (Ollama)
本项目使用轻量级、响应迅速的 `Gemma:2b` 大模型。您需要先在本地安装 [Ollama](https://ollama.com/) 并下载模型：
```bash
# 启动 Ollama 后运行以下命令下载 Gemma:2b
ollama run gemma:2b
```

### 2. 后端部署 (FastAPI)
后端基于 Python 3.10+ 构建。

```bash
# 进入后端目录
cd backend

# 创建并激活虚拟环境
python3 -m venv venv
source venv/bin/activate

# 安装依赖
pip install -r requirements.txt

# 启动服务 (默认监听 http://127.0.0.1:8000)
uvicorn main:app --reload
```

> 💡 **提示**：启动后可访问 `http://127.0.0.1:8000/docs` 查看交互式 API 文档 (Swagger UI)。

### 3. iOS 客户端运行 (SwiftUI)
1. 在 macOS 上使用 **Xcode (15.0+)** 打开 `frontend/ios/AIFinance.xcodeproj` 项目。
2. 确保模拟器或真机的系统版本为 **iOS 16.0** 以上。
3. 选择一个 iPhone 模拟器并点击 **Run** (Cmd + R)。
4. 如果您的 FastAPI 运行在非本地或有特殊的 IP，请在 `NetworkManager.swift` 中修改 `baseURL`。

---

## 📂 项目结构

```text
ai-finance/
├── backend/
│   ├── main.py            # FastAPI 路由与主入口
│   ├── database.py        # SQLAlchemy 数据库连接 (SQLite)
│   ├── models.py          # 账单数据库模型
│   ├── schemas.py         # Pydantic 校验模型
│   └── requirements.txt   # 后端依赖列表
├── core/
│   └── gemma_agent/
│       ├── agent.py       # Gemma 大模型接口与正则降级引擎
│       ├── prompts.py     # 智能解析及顾问 Prompts 模板
│       └── requirements.txt
├── frontend/
│   └── ios/
│       ├── AIFinance.xcodeproj    # Xcode 项目结构
│       ├── AIFinanceApp.swift     # SwiftUI 主入口
│       ├── Models.swift           # 前端数据结构定义
│       ├── NetworkManager.swift   # HTTP 异步请求封装
│       └── Views/
│           ├── DashboardView.swift  # 首页资产看板及图表
│           ├── ChatView.swift       # 智能对话记账界面
│           ├── TransactionListView.swift # 历史明细与删除
│           └── AddTransactionView.swift  # 手动记账表单
└── README.md
```

---

## 🔒 开源协议
本项目采用 [MIT License](LICENSE) 许可协议。
