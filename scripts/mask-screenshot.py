#!/usr/bin/env python3
"""
Azure Portal 스크린샷에서 민감 정보(구독명 등)를 마스킹하는 스크립트.

사용법:
  python scripts/mask-screenshot.py <이미지파일> [--text "마스킹할 텍스트"] [--output 출력파일]

예시:
  # 기본: 구독명 자동 마스킹 (흰색 박스 + "<your-subscription>" 텍스트)
  python scripts/mask-screenshot.py infra-foundry-classic/basic/images/step1-create-resource-group.png

  # 특정 텍스트 마스킹
  python scripts/mask-screenshot.py screenshot.png --text "ME-MngEnvMCAP132261-moonchoi-1"

  # 출력 파일 지정
  python scripts/mask-screenshot.py screenshot.png --output masked.png
"""

import argparse
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


def find_text_region_by_color(img: Image.Image, target_text_area: tuple = None):
    """구독명이 있을 법한 드롭다운 영역을 찾아 반환."""
    # Azure Portal의 구독 드롭다운은 보통 이미지의 오른쪽 절반, 상단 40~70% 영역
    w, h = img.size
    # 기본 영역: 이미지 전체를 스캔하여 입력 필드 찾기
    return target_text_area


def mask_region(img: Image.Image, region: tuple, replacement_text: str = "<your-subscription>"):
    """지정된 영역을 흰색 박스로 덮고 대체 텍스트를 삽입."""
    draw = ImageDraw.Draw(img)
    x1, y1, x2, y2 = region

    # 흰색 박스로 덮기
    draw.rectangle([x1, y1, x2, y2], fill="white")

    # 대체 텍스트 삽입
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 14)
    except (OSError, IOError):
        font = ImageFont.load_default()

    text_bbox = draw.textbbox((0, 0), replacement_text, font=font)
    text_w = text_bbox[2] - text_bbox[0]
    text_h = text_bbox[3] - text_bbox[1]
    text_x = x1 + ((x2 - x1) - text_w) // 2
    text_y = y1 + ((y2 - y1) - text_h) // 2
    draw.text((text_x, text_y), replacement_text, fill="#666666", font=font)

    return img


def auto_detect_subscription_region(img: Image.Image):
    """Azure Portal 스크린샷에서 구독명 영역을 자동 탐지.
    일반적인 Azure Portal 레이아웃 기반 휴리스틱."""
    w, h = img.size
    pixels = img.load()

    # Azure Portal 드롭다운 영역 패턴: 회색 테두리 안의 텍스트
    # 대략 이미지의 오른쪽 40~85%, 세로 위치는 구독 라벨 근처
    # 휴리스틱: "Subscription" 라벨 옆의 드롭다운 박스 찾기
    # 일반적으로 이미지 폭의 45~85%, 높이의 35~55% 영역

    candidate_x1 = int(w * 0.38)
    candidate_x2 = int(w * 0.85)
    candidate_y1 = int(h * 0.38)
    candidate_y2 = int(h * 0.48)

    return (candidate_x1, candidate_y1, candidate_x2, candidate_y2)


def mask_screenshot(
    input_path: str,
    output_path: str = None,
    region: tuple = None,
    replacement_text: str = "<your-subscription>",
):
    """스크린샷을 마스킹 처리."""
    img = Image.open(input_path)

    if region is None:
        region = auto_detect_subscription_region(img)
        print(f"  자동 탐지 영역: {region}")

    img = mask_region(img, region, replacement_text)

    if output_path is None:
        output_path = input_path  # 덮어쓰기

    img.save(output_path)
    print(f"  ✅ 마스킹 완료: {output_path}")
    return output_path


def main():
    parser = argparse.ArgumentParser(description="Azure Portal 스크린샷 민감 정보 마스킹")
    parser.add_argument("image", help="마스킹할 이미지 파일 경로")
    parser.add_argument("--output", "-o", help="출력 파일 경로 (기본: 원본 덮어쓰기)")
    parser.add_argument("--text", "-t", default="<your-subscription>", help="대체 텍스트")
    parser.add_argument(
        "--region", "-r",
        help="마스킹 영역 (x1,y1,x2,y2). 미지정 시 자동 탐지",
        default=None,
    )

    args = parser.parse_args()

    if not Path(args.image).exists():
        print(f"❌ 파일을 찾을 수 없습니다: {args.image}")
        sys.exit(1)

    region = None
    if args.region:
        region = tuple(int(x) for x in args.region.split(","))

    mask_screenshot(args.image, args.output, region, args.text)


if __name__ == "__main__":
    main()
