<script>
import { useAlert } from 'dashboard/composables';
import NextButton from 'dashboard/components-next/button/Button.vue';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength, email } from '@vuelidate/validators';
export default {
  components: {
    NextButton,
  },
  props: {
    name: {
      type: String,
      default: '',
    },
    email: {
      type: String,
      default: '',
    },
    displayName: {
      type: String,
      default: '',
    },
    preferredLanguage: {
      type: String,
      default: 'ko',
    },
    emailEnabled: {
      type: Boolean,
      default: false,
    },
  },
  emits: ['updateUser'],
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      userName: this.name,
      userDisplayName: this.displayName,
      userEmail: this.email,
      userPreferredLanguage: this.preferredLanguage,
      languageOptions: [
        { key: 'ko', label: '한국어' },
        { key: 'en', label: 'English' },
        { key: 'ja', label: '日本語' },
        { key: 'zh', label: '中文' },
        { key: 'es', label: 'Español' },
        { key: 'fr', label: 'Français' },
        { key: 'de', label: 'Deutsch' },
        { key: 'pt', label: 'Português' },
        { key: 'ru', label: 'Русский' },
        { key: 'ar', label: 'العربية' },
      ],
      inputStyles: {
        borderRadius: '0.75rem',
        padding: '0.375rem 0.75rem',
        fontSize: '0.875rem',
        marginBottom: '0.125rem',
      },
    };
  },
  validations: {
    userName: {
      required,
      minLength: minLength(1),
    },
    userDisplayName: {},
    userEmail: {
      required,
      email,
    },
  },
  watch: {
    name: {
      handler(value) {
        this.userName = value;
      },
      immediate: true,
    },
    displayName: {
      handler(value) {
        this.userDisplayName = value;
      },
      immediate: true,
    },
    email: {
      handler(value) {
        this.userEmail = value;
      },
      immediate: true,
    },
    preferredLanguage: {
      handler(value) {
        console.log('UserBasicDetails: preferredLanguage prop changed to:', value);
        this.userPreferredLanguage = value;
        console.log('UserBasicDetails: userPreferredLanguage set to:', this.userPreferredLanguage);
      },
      immediate: true,
    },
  },
  methods: {
    async updateUser() {
      this.v$.$touch();
      if (this.v$.$invalid) {
        useAlert(this.$t('PROFILE_SETTINGS.FORM.ERROR'));
        return;
      }
      this.$emit('updateUser', {
        name: this.userName,
        displayName: this.userDisplayName,
        email: this.userEmail,
        preferredLanguage: this.userPreferredLanguage,
      });
    },
  },
};
</script>

<template>
  <form class="flex flex-col gap-4" @submit.prevent="updateUser('profile')">
    <woot-input
      v-model="userName"
      :styles="inputStyles"
      :class="{ error: v$.userName.$error }"
      :label="$t('PROFILE_SETTINGS.FORM.NAME.LABEL')"
      :placeholder="$t('PROFILE_SETTINGS.FORM.NAME.PLACEHOLDER')"
      :error="`${
        v$.userName.$error ? $t('PROFILE_SETTINGS.FORM.NAME.ERROR') : ''
      }`"
      @input="v$.userName.$touch"
      @blur="v$.userName.$touch"
    />
    <woot-input
      v-model="userDisplayName"
      :styles="inputStyles"
      :class="{ error: v$.userDisplayName.$error }"
      :label="$t('PROFILE_SETTINGS.FORM.DISPLAY_NAME.LABEL')"
      :placeholder="$t('PROFILE_SETTINGS.FORM.DISPLAY_NAME.PLACEHOLDER')"
      :error="`${
        v$.userDisplayName.$error
          ? $t('PROFILE_SETTINGS.FORM.DISPLAY_NAME.ERROR')
          : ''
      }`"
      @input="v$.userDisplayName.$touch"
      @blur="v$.userDisplayName.$touch"
    />
    <woot-input
      v-if="emailEnabled"
      v-model="userEmail"
      :styles="inputStyles"
      :class="{ error: v$.userEmail.$error }"
      :label="$t('PROFILE_SETTINGS.FORM.EMAIL.LABEL')"
      :placeholder="$t('PROFILE_SETTINGS.FORM.EMAIL.PLACEHOLDER')"
      :error="`${
        v$.userEmail.$error ? $t('PROFILE_SETTINGS.FORM.EMAIL.ERROR') : ''
      }`"
      @input="v$.userEmail.$touch"
      @blur="v$.userEmail.$touch"
    />
    <div class="pb-4">
      <label class="block text-sm font-medium text-gray-700 mb-2">
        {{ $t('PROFILE_SETTINGS.FORM.PREFERRED_LANGUAGE.LABEL') }}
      </label>
      <select
        v-model="userPreferredLanguage"
        :style="inputStyles"
        class="w-full border border-gray-300 focus:ring-blue-500 focus:border-blue-500"
      >
        <option
          v-for="option in languageOptions"
          :key="option.key"
          :value="option.key"
        >
          {{ option.label }}
        </option>
      </select>
      <p class="text-xs text-gray-500 mt-1">
        {{ $t('PROFILE_SETTINGS.FORM.PREFERRED_LANGUAGE.HELP_TEXT') }}
      </p>
    </div>
    <div>
      <NextButton type="submit" :label="$t('PROFILE_SETTINGS.BTN_TEXT')" />
    </div>
  </form>
</template>
