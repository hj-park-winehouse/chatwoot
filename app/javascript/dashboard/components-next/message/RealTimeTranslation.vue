<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const props = defineProps({
  contentAttributes: {
    type: Object,
    default: () => ({}),
  },
});

// props가 업데이트될 때마다 자동으로 반응하도록 computed 사용
const translationsData = computed(() => ({
  google: props.contentAttributes?.realtimeTranslations?.google || null,
  meta: props.contentAttributes?.realtimeTranslations?.meta || null,
}));

const isLoading = ref(false);

// 번역 결과가 있는지 확인
const hasTranslations = computed(() => {
  return (
    (translationsData.value.google && translationsData.value.google.content) ||
    (translationsData.value.meta && translationsData.value.meta.content)
  );
});

// 번역 결과나 로딩 중일 때 박스를 보여줌
const showTranslationBox = computed(() => {
  return hasTranslations.value || isLoading.value;
});

// 컴포넌트 마운트 시 디버깅 로그
onMounted(() => {
  console.log('RealTimeTranslation onMounted:');
  console.log('- props.contentAttributes:', props.contentAttributes);
  console.log(
    '- props.contentAttributes?.realtimeTranslations:',
    props.contentAttributes?.realtimeTranslations
  );
  console.log(
    '- typeof props.contentAttributes:',
    typeof props.contentAttributes
  );
  console.log(
    '- Object.keys(props.contentAttributes || {}):',
    Object.keys(props.contentAttributes || {})
  );
  console.log('- computed translationsData:', translationsData.value);
});

// props 변경 감지
watch(
  () => props.contentAttributes?.realtimeTranslations,
  (newTranslations, oldTranslations) => {
    console.log('RealTimeTranslation: Props updated!');
    console.log('- old:', oldTranslations);
    console.log('- new:', newTranslations);
    console.log('- translationsData updated:', translationsData.value);
  },
  { deep: true }
);

const clickTest = () => {
  console.log('Test click event');
  // 여기에 클릭 이벤트 로직 추가
  console.log('props:', props);
};
</script>

<template>
  <div class="translation-container" @click="clickTest">
    <!-- 번역 결과 박스 -->
    <div v-if="showTranslationBox" class="translation-reply-box">
      <div class="translation-reply-box__top">
        <!-- 번역 결과들 -->
        <div class="translations-section">
          <div v-if="isLoading" class="translation-loading">
            <Spinner size="small" />
            <span>{{ $t('CONVERSATION.TRANSLATING') }}</span>
          </div>

          <div
            v-if="translationsData.google && translationsData.google.content"
            class="translation-result"
          >
            <div class="provider-tag">
              {{ $t('CONVERSATION.TRANSLATION_PROVIDERS.GOOGLE') }}
            </div>
            <div class="translation-content">
              {{ translationsData.google.content }}
            </div>
          </div>

          <div
            v-if="translationsData.meta && translationsData.meta.content"
            class="translation-result"
          >
            <div class="provider-tag">
              {{ $t('CONVERSATION.TRANSLATION_PROVIDERS.META') }}
            </div>
            <div class="translation-content">
              {{ translationsData.meta.content }}
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.translation-container {
  margin-top: 8px;
}

/* 번역 박스 - 명확히 구분되는 스타일 */
.translation-reply-box {
  position: relative;
  margin: 12px 0 8px 0;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  background: #f8fafc;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
}

.translation-reply-box__top {
  position: relative;
  padding: 16px;
}

.translations-section {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.translation-loading {
  display: flex;
  align-items: center;
  gap: 8px;
  color: #64748b;
  font-size: 14px;
  padding: 12px;
  background: #f1f5f9;
  border-radius: 6px;
  border: 1px solid #e2e8f0;
}

.translation-result {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.provider-tag {
  display: inline-flex;
  align-items: center;
  padding: 4px 12px;
  border-radius: 16px;
  background: #3b82f6;
  font-size: 11px;
  font-weight: 600;
  color: #ffffff;
  width: fit-content;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.translation-content {
  font-size: 14px;
  color: #1e293b;
  background: #ffffff;
  border-radius: 6px;
  padding: 14px;
  border: 1px solid #e2e8f0;
  border-left: 4px solid #3b82f6;
  line-height: 1.5;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.05);
}

/* Dark theme support */
.dark .translation-reply-box {
  background: #1e293b;
  border-color: #334155;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.3);
}

.dark .translation-content {
  background: #0f172a;
  color: #e2e8f0;
  border-color: #334155;
  border-left-color: #60a5fa;
}

.dark .provider-tag {
  background: #1d4ed8;
  color: #ffffff;
}

.dark .translation-loading {
  background: #0f172a;
  border-color: #334155;
  color: #94a3b8;
}
</style>
