# Contributing to AI Finance

Thank you for your interest in contributing to AI Finance! 🎉

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR_USERNAME/ai-finance.git`
3. Create a feature branch: `git checkout -b feature/your-feature`
4. Commit your changes: `git commit -m "feat: add your feature"`
5. Push and open a Pull Request

## Development Setup

### Backend (Python)
```bash
cd backend
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --reload
```

### iOS (SwiftUI)
Open `frontend/ios/AIFinance.xcodeproj` in Xcode 15+ and run on an iOS 16+ simulator.

### Gemma Model
```bash
ollama run gemma:2b
```

## Guidelines

- Follow existing code style and conventions
- Write clear commit messages using [Conventional Commits](https://www.conventionalcommits.org/)
- Add tests for new features when possible
- Update documentation for API changes

## Reporting Issues

Use GitHub Issues with the provided templates. Include reproduction steps and environment details.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
