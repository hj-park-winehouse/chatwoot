<script setup>
import { computed, ref } from 'vue';
import BaseBubble from 'next/message/bubbles/Base.vue';
import FormattedContent from './FormattedContent.vue';
import AttachmentChips from 'next/message/chips/AttachmentChips.vue';
import TranslationToggle from 'dashboard/components-next/message/TranslationToggle.vue';
import RealTimeTranslation from 'dashboard/components-next/message/RealTimeTranslation.vue';
import { MESSAGE_TYPES } from '../../constants';
import { useMessageContext } from '../../provider.js';
import { useTranslations } from 'dashboard/composables/useTranslations';

const {
  content,
  attachments,
  contentAttributes,
  messageType,
  id,
  conversationId,
} = useMessageContext();

const { hasTranslations, translationContent } =
  useTranslations(contentAttributes);

const renderOriginal = ref(false);

const renderContent = computed(() => {
  console.log('Text/Index renderContent computed:', {
    renderOriginal: renderOriginal.value,
    hasTranslations: hasTranslations.value,
    translationContent: translationContent.value,
    contentValue: content.value,
    typeOfTranslationContent: typeof translationContent.value,
  });

  if (renderOriginal.value) {
    return content.value;
  }

  if (hasTranslations.value) {
    console.log(
      'Text/Index: Using translationContent:',
      translationContent.value
    );
    return translationContent.value;
  }

  console.log('Text/Index: Using original content:', content.value);
  return content.value;
});

const isTemplate = computed(() => {
  return messageType.value === MESSAGE_TYPES.TEMPLATE;
});

const isEmpty = computed(() => {
  return !content.value && !attachments.value?.length;
});

const handleSeeOriginal = () => {
  renderOriginal.value = !renderOriginal.value;
};
</script>

<template>
  <BaseBubble class="px-4 py-3" data-bubble-name="text">
    <div class="gap-3 flex flex-col">
      <span v-if="isEmpty" class="text-n-slate-11">
        {{ $t('CONVERSATION.NO_CONTENT') }}
      </span>
      <FormattedContent v-if="renderContent" :content="renderContent" />
      <TranslationToggle
        v-if="hasTranslations"
        class="-mt-3"
        :showing-original="renderOriginal"
        @toggle="handleSeeOriginal"
      />
      <!-- 실시간 번역 컴포넌트 -->
      <RealTimeTranslation
        v-if="content && !isEmpty"
        :message-id="id"
        :content="content"
        :conversation-id="conversationId"
        :content-attributes="contentAttributes"
      />
      <AttachmentChips :attachments="attachments" class="gap-2" />
      <template v-if="isTemplate">
        <div
          v-if="contentAttributes.submittedEmail"
          class="px-2 py-1 rounded-lg bg-n-alpha-3"
        >
          {{ contentAttributes.submittedEmail }}
        </div>
      </template>
    </div>
  </BaseBubble>
</template>

<style>
p:last-child {
  margin-bottom: 0;
}
</style>
