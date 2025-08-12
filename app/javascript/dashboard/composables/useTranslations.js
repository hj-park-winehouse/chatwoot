import { computed } from 'vue';

/**
 * Composable to extract translation state/content from contentAttributes.
 * @param {Ref|Reactive} contentAttributes - Ref or reactive object containing `translations` property
 * @returns {Object} { hasTranslations, translationContent }
 */
export function useTranslations(contentAttributes) {
  const hasTranslations = computed(() => {
    if (!contentAttributes.value) return false;
    const { translations = {} } = contentAttributes.value;
    console.log('useTranslations hasTranslations check:', {
      contentAttributes: contentAttributes.value,
      translations,
      hasTranslations: Object.keys(translations || {}).length > 0,
    });
    return Object.keys(translations || {}).length > 0;
  });

  const translationContent = computed(() => {
    if (!hasTranslations.value) return null;
    const translations = contentAttributes.value.translations;
    const firstKey = Object.keys(translations)[0];
    const firstTranslation = translations[firstKey];
    
    // 기존 구조에서 실제 번역 텍스트 추출
    let content;
    if (typeof firstTranslation === 'object' && firstTranslation.content) {
      // 객체 형태: {content: "번역된 내용", targetLanguage: "ko", ...}
      content = firstTranslation.content;
    } else if (typeof firstTranslation === 'string') {
      // 문자열 형태: "번역된 내용"
      content = firstTranslation;
    } else {
      content = null;
    }
    
    console.log('useTranslations translationContent:', {
      translations,
      firstKey,
      firstTranslation,
      extractedContent: content,
      typeOfExtractedContent: typeof content,
    });
    
    return content;
  });

  return { hasTranslations, translationContent };
}
