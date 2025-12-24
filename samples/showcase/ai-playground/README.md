# AI Playground Showcase

Demonstration of Zylix AI/ML integration capabilities.

## Overview

This showcase demonstrates AI integration features:
- Speech recognition (Whisper)
- Text-to-Speech synthesis
- Image classification
- Object detection
- Natural language processing

## Project Structure

```
ai-playground/
├── README.md
├── core/
│   ├── build.zig
│   └── src/
│       ├── main.zig        # Entry point
│       ├── app.zig         # App state
│       └── playground.zig  # AI playground UI
└── platforms/
```

## Features

### Speech Recognition
- Whisper-based transcription
- Real-time voice input
- Multi-language support
- Confidence scores

### Text-to-Speech
- Neural voice synthesis
- Voice selection
- Speed and pitch control

### Image AI
- Image classification
- Object detection
- Face detection
- Style transfer

### NLP
- Text summarization
- Sentiment analysis
- Translation
- Named entity recognition

## Quick Start

```bash
cd core && zig build
zig build test
zig build wasm
```

## Demo Modes

1. **Voice**: Speech-to-text transcription
2. **Vision**: Image analysis and detection
3. **Text**: NLP and text processing
4. **Chat**: Conversational AI demo

## Related Showcases

- [Animation Studio](../animation-studio/) - Animation system
- [Component Gallery](../component-gallery/) - UI components

## License

MIT License
