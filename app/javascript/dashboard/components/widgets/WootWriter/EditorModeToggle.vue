<script setup>
import { computed, useTemplateRef } from 'vue';
import { useElementSize } from '@vueuse/core';
import { REPLY_EDITOR_MODES } from './constants';

const props = defineProps({
  mode: {
    type: String,
    default: REPLY_EDITOR_MODES.REPLY,
  },
});

const emit = defineEmits(['setReplyMode']);

const wootEditorReplyMode = useTemplateRef('wootEditorReplyMode');
const wootEditorPrivateMode = useTemplateRef('wootEditorPrivateMode');
const wootEditorTranslateMode = useTemplateRef('wootEditorTranslateMode');

const replyModeSize = useElementSize(wootEditorReplyMode);
const privateModeSize = useElementSize(wootEditorPrivateMode);
const translateModeSize = useElementSize(wootEditorTranslateMode);

/**
 * Computed boolean indicating if the editor is in private note mode
 * @type {ComputedRef<boolean>}
 */
const isPrivate = computed(() => props.mode === REPLY_EDITOR_MODES.NOTE);

/**
 * Computed boolean indicating if the editor is in translate mode
 * @type {ComputedRef<boolean>}
 */
const isTranslate = computed(() => props.mode === REPLY_EDITOR_MODES.TRANSLATE);

/**
 * Computes the width of the sliding background chip in pixels
 * Includes 16px of padding in the calculation
 * @type {ComputedRef<string>}
 */
const width = computed(() => {
  let widthToUse;
  if (isTranslate.value) {
    widthToUse = translateModeSize.width.value;
  } else if (isPrivate.value) {
    widthToUse = privateModeSize.width.value;
  } else {
    widthToUse = replyModeSize.width.value;
  }

  const widthWithPadding = widthToUse + 16;
  return `${widthWithPadding}px`;
});

/**
 * Computes the X translation value for the sliding background chip
 * Translates by the width of reply mode + padding when in private mode
 * @type {ComputedRef<string>}
 */
const translateValue = computed(() => {
  let xTranslate = 0;
  if (isTranslate.value) {
    xTranslate = replyModeSize.width.value + privateModeSize.width.value + 32;
  } else if (isPrivate.value) {
    xTranslate = replyModeSize.width.value + 16;
  }

  return `${xTranslate}px`;
});

const handleModeClick = mode => {
  emit('setReplyMode', mode);
};
</script>

<template>
  <div class="flex items-center w-auto h-8 p-1 transition-all border rounded-full bg-n-alpha-2 group relative duration-300 ease-in-out z-0">
    <button
      ref="wootEditorReplyMode"
      class="flex items-center gap-1 px-2 z-20 cursor-pointer"
      @click="handleModeClick(REPLY_EDITOR_MODES.REPLY)"
    >
      {{ $t('CONVERSATION.REPLYBOX.REPLY') }}
    </button>
    <button
      ref="wootEditorPrivateMode"
      class="flex items-center gap-1 px-2 z-20 cursor-pointer"
      @click="handleModeClick(REPLY_EDITOR_MODES.NOTE)"
    >
      {{ $t('CONVERSATION.REPLYBOX.PRIVATE_NOTE') }}
    </button>
    <button
      ref="wootEditorTranslateMode"
      class="flex items-center gap-1 px-2 z-20 cursor-pointer"
      @click="handleModeClick(REPLY_EDITOR_MODES.TRANSLATE)"
    >
      {{ $t('CONVERSATION.REPLYBOX.TRANSLATE') }}
    </button>
    <div
      class="absolute shadow-sm rounded-full h-6 w-[var(--chip-width)] transition-all duration-300 ease-in-out translate-x-[var(--translate-x)] rtl:translate-x-[var(--rtl-translate-x)] bg-n-solid-1"
      :style="{
        '--chip-width': width,
        '--translate-x': translateValue,
        '--rtl-translate-x': `calc(-1 * var(--translate-x))`,
      }"
    />
  </div>
</template>
