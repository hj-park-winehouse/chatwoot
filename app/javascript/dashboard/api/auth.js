/* global axios */

import Cookies from 'js-cookie';
import endPoints from './endPoints';
import {
  clearCookiesOnLogout,
  deleteIndexedDBOnLogout,
} from '../store/utils/api';

export default {
  validityCheck() {
    const urlData = endPoints('validityCheck');
    return axios.get(urlData.url);
  },
  logout() {
    const urlData = endPoints('logout');
    const fetchPromise = new Promise((resolve, reject) => {
      axios
        .delete(urlData.url)
        .then(response => {
          deleteIndexedDBOnLogout();
          clearCookiesOnLogout();
          resolve(response);
        })
        .catch(error => {
          reject(error);
        });
    });
    return fetchPromise;
  },
  hasAuthCookie() {
    return !!Cookies.get('cw_d_session_info');
  },
  getAuthData() {
    if (this.hasAuthCookie()) {
      const savedAuthInfo = Cookies.get('cw_d_session_info');
      return JSON.parse(savedAuthInfo || '{}');
    }
    return false;
  },
  profileUpdate({ displayName, avatar, ...profileAttributes }) {
    console.log('profileUpdate called with:', {
      displayName,
      avatar,
      profileAttributes,
    });
    const formData = new FormData();
    Object.keys(profileAttributes).forEach(key => {
      const hasValue = profileAttributes[key] !== undefined;
      console.log(
        `Processing key: ${key}, value: ${profileAttributes[key]}, hasValue: ${hasValue}`
      );
      if (hasValue) {
        // Convert camelCase to snake_case for Rails compatibility
        let railsKey = key;
        if (key === 'preferredLanguage') {
          railsKey = 'preferred_language';
        } else if (key === 'autoTranslate') {
          railsKey = 'auto_translate';
        }
        formData.append(`profile[${railsKey}]`, profileAttributes[key]);
        console.log(
          `Added to formData: profile[${railsKey}] = ${profileAttributes[key]}`
        );
      }
    });
    formData.append('profile[display_name]', displayName || '');
    console.log(
      `Added to formData: profile[display_name] = ${displayName || ''}`
    );
    if (avatar) {
      formData.append('profile[avatar]', avatar);
      console.log('Added avatar to formData');
    }

    // FormData 내용을 확인하기 위한 로그
    console.log('Final FormData entries:');
    Array.from(formData.entries()).forEach(pair => {
      console.log(`${pair[0]}: ${pair[1]}`);
    });

    return axios.put(endPoints('profileUpdate').url, formData);
  },

  profilePasswordUpdate({ currentPassword, password, passwordConfirmation }) {
    return axios.put(endPoints('profileUpdate').url, {
      profile: {
        current_password: currentPassword,
        password,
        password_confirmation: passwordConfirmation,
      },
    });
  },

  updateUISettings({ uiSettings }) {
    return axios.put(endPoints('profileUpdate').url, {
      profile: { ui_settings: uiSettings },
    });
  },

  updateAvailability(availabilityData) {
    return axios.post(endPoints('availabilityUpdate').url, {
      profile: { ...availabilityData },
    });
  },

  updateAutoOffline(accountId, autoOffline = false) {
    return axios.post(endPoints('autoOffline').url, {
      profile: { account_id: accountId, auto_offline: autoOffline },
    });
  },

  deleteAvatar() {
    return axios.delete(endPoints('deleteAvatar').url);
  },

  resetPassword({ email }) {
    const urlData = endPoints('resetPassword');
    return axios.post(urlData.url, { email });
  },

  setActiveAccount({ accountId }) {
    const urlData = endPoints('setActiveAccount');
    return axios.put(urlData.url, {
      profile: {
        account_id: accountId,
      },
    });
  },
  resendConfirmation() {
    const urlData = endPoints('resendConfirmation');
    return axios.post(urlData.url);
  },
  resetAccessToken() {
    const urlData = endPoints('resetAccessToken');
    return axios.post(urlData.url);
  },
};
