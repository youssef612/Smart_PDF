"""
Smart PDF Extractor Server — docling edition
Port: 7070
"""

import os
import re
import tempfile
from pypdf import PdfReader
import uvicorn
from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional


# ── SmartPDFExtractor ──────────────────────────────────────────

class SmartPDFExtractor:
    PATTERNS = {
        'math':    re.compile(r'\$[^\$]+\$|\\frac|\\sum|\\int|\\alpha|\\beta|\\theta|\\infty|\\sqrt|\\partial'),
        'code':    re.compile(r'```[\s\S]{10,}?```|\bdef \w|\bclass \w|\bimport \w|\bfor .+ in |\bif __name__'),
        'tables':  re.compile(r'\|[-\s|:]{10,}\|'),
        'proofs':  re.compile(r'\bProof[.:]|\bTheorem\b|\bLemma\b|\bCorollary\b|\bQ\.E\.D|■'),
        'figures': re.compile(r'Figure \d+|Fig\.\s*\d+|\[Image\]|\[Figure\]'),
    }

    STRUCTURE_PATTERNS = {
        'chapter': re.compile(r'^#{1,2}\s*(Chapter|الفصل)\s*(\d+|[IVX]+)', re.MULTILINE | re.IGNORECASE),
        'section': re.compile(r'^#{2,3}\s*\d+\.\d+|^#{2,3}\s*\w', re.MULTILINE),
    }

    def __init__(self):
        self._converter = None

    def _load_models(self):
        """تحميل docling — مرة واحدة بس (lazy load)"""
        if self._converter is not None:
            print('ℹ️ Models already loaded — skipping')
            return
        print('⏳ Loading docling converter...')
        try:
            from docling.document_converter import DocumentConverter
            self._converter = DocumentConverter()
            print('✅ Docling converter ready!')
        except Exception as e:
            raise RuntimeError(f'فشل تحميل docling: {e}') from e

    def extract(self, pdf_path: str) -> dict:
        if not os.path.exists(pdf_path):
            raise FileNotFoundError(f'الملف مش موجود: {pdf_path}')

        self._load_models()

        # استخراج النص بـ docling
        result     = self._converter.convert(pdf_path)
        full_text  = result.document.export_to_markdown()

        if not full_text.strip():
            raise ValueError('الاستخراج رجع نص فاضي')

        # عدد الصفحات الحقيقي من pypdf
        reader          = PdfReader(pdf_path)
        real_page_count = len(reader.pages)

        pages = []
        for i, page in enumerate(reader.pages):
            text = page.extract_text() or ""
            pages.append({
                "page_number": i + 1,
                "text":        text.strip(),
                "has_text":    bool(text.strip())
            })

        if not any(p["has_text"] for p in pages):
            pages = self._split_pages(full_text)

        content_flags = self._detect_content(full_text)
        structure     = self._extract_structure(full_text)
        quality       = self._assess_quality(full_text, pages)

        print(f'✅ Done: {real_page_count} pages | {len(full_text):,} chars | quality: {quality}')

        return {
            'full_text'    : full_text,
            'pages'        : pages,
            'page_count'   : real_page_count,
            'total_chars'  : len(full_text),
            'content_flags': content_flags,
            'structure'    : structure,
            'quality'      : quality,
        }

    def _detect_content(self, text: str) -> dict:
        return {f'has_{k}': bool(p.search(text)) for k, p in self.PATTERNS.items()}

    def _extract_structure(self, text: str) -> dict:
        structure = {}
        for key, pattern in self.STRUCTURE_PATTERNS.items():
            matches = pattern.findall(text)
            structure[f'{key}s'] = [m if isinstance(m, str) else m[0] for m in matches[:50]]
        return structure

    def _split_pages(self, text: str) -> list:
        pages = [p.strip() for p in text.split('\x0c') if p.strip()]
        if len(pages) <= 1:
            chunks = [p.strip() for p in re.split(r'\n{3,}', text) if p.strip()]
            pages  = chunks if chunks else [text.strip()]
        return pages

    def _assess_quality(self, text: str, pages: list) -> str:
        if not text:
            return 'poor'
        avg_page_len = len(text) / max(len(pages), 1)
        broken       = len(re.findall(r'\ufffd|\x00|\xfe\xff', text))
        ratio        = broken / max(len(text), 1)
        if ratio > 0.05 or avg_page_len < 50:  return 'poor'
        if ratio > 0.01 or avg_page_len < 200: return 'fair'
        return 'good'

    def chunk_text(self, text: str, chunk_size: int = 5000, overlap: int = 200) -> list:
        paragraphs  = re.split(r'\n{2,}', text)
        chunks, current, current_len = [], '', 0
        for para in paragraphs:
            para_len = len(para)
            if current_len + para_len > chunk_size and current:
                chunks.append({'index': len(chunks), 'text': current.strip(), 'char_len': len(current)})
                current     = current[-overlap:] + '\n\n' + para if overlap else para
                current_len = len(current)
            else:
                current     += '\n\n' + para
                current_len += para_len
        if current.strip():
            chunks.append({'index': len(chunks), 'text': current.strip(), 'char_len': len(current)})
        return chunks


extractor = SmartPDFExtractor()


# ── FastAPI App ────────────────────────────────────────────────

app = FastAPI(title='Smart PDF Extractor — docling')
app.add_middleware(
    CORSMiddleware,
    allow_origins=['*'],
    allow_methods=['*'],
    allow_headers=['*'],
)


class PathRequest(BaseModel):
    path       : Optional[str] = None
    drive_path : Optional[str] = None
    colab_path : Optional[str] = None
    chunk_size : Optional[int] = 5000
    overlap    : Optional[int] = 200

class TextRequest(BaseModel):
    text: str


def _resolve_path(req: PathRequest) -> str:
    p = req.drive_path or req.colab_path or req.path
    if not p:
        raise HTTPException(400, 'ابعت drive_path أو colab_path أو path')
    if not os.path.exists(p):
        raise HTTPException(404, f'الملف مش موجود: {p}')
    return p


@app.get('/')
def root():
    return {'status': 'ok', 'service': 'smart-pdf-extractor-docling'}

@app.get('/health')
def health():
    return {'status': 'ok', 'model_loaded': extractor._converter is not None}


@app.post('/extract')
async def extract_upload(file: UploadFile = File(...)):
    if not file.filename.lower().endswith('.pdf'):
        raise HTTPException(400, 'ارفع ملف PDF بس')
    tmp_path = None
    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix='.pdf') as tmp:
            tmp.write(await file.read())
            tmp_path = tmp.name
        result = extractor.extract(tmp_path)
        result['filename'] = file.filename
        return JSONResponse(result)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(500, f'extract error: {e}')
    finally:
        if tmp_path and os.path.exists(tmp_path):
            os.unlink(tmp_path)


@app.post('/extract_path')
async def extract_path_endpoint(req: PathRequest):
    pdf_path = _resolve_path(req)
    try:
        result = extractor.extract(pdf_path)
        return JSONResponse(result)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(500, f'extract_path error: {e}')


@app.post('/extract_chunks')
async def extract_chunks_upload(file: UploadFile = File(...),
                                 chunk_size: int = 5000,
                                 overlap   : int = 200):
    if not file.filename.lower().endswith('.pdf'):
        raise HTTPException(400, 'ارفع ملف PDF بس')
    tmp_path = None
    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix='.pdf') as tmp:
            tmp.write(await file.read())
            tmp_path = tmp.name
        result = extractor.extract(tmp_path)
        chunks = extractor.chunk_text(result['full_text'], chunk_size, overlap)
        return JSONResponse({
            'chunks'       : chunks,
            'chunk_count'  : len(chunks),
            'total_chars'  : result['total_chars'],
            'content_flags': result['content_flags'],
            'structure'    : result['structure'],
            'quality'      : result['quality'],
        })
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(500, f'extract_chunks error: {e}')
    finally:
        if tmp_path and os.path.exists(tmp_path):
            os.unlink(tmp_path)


@app.post('/extract_chunks_path')
async def extract_chunks_path_endpoint(req: PathRequest):
    pdf_path = _resolve_path(req)
    try:
        result = extractor.extract(pdf_path)
        chunks = extractor.chunk_text(result['full_text'], req.chunk_size, req.overlap)
        return JSONResponse({
            'chunks'       : chunks,
            'chunk_count'  : len(chunks),
            'total_chars'  : result['total_chars'],
            'content_flags': result['content_flags'],
            'structure'    : result['structure'],
            'quality'      : result['quality'],
        })
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(500, f'extract_chunks_path error: {e}')


@app.post('/detect_content')
async def detect_content(req: TextRequest):
    if not req.text:
        raise HTTPException(400, 'text مطلوب')
    flags = extractor._detect_content(req.text)
    return JSONResponse({'content_flags': flags})


# ── Entry point ───────────────────────────────────────────────

if __name__ == '__main__':
    print('⏳ Pre-loading docling models...')
    extractor._load_models()
    print('🚀 Starting server on port 7070...')
    uvicorn.run(app, host='0.0.0.0', port=7070, log_level='info')
