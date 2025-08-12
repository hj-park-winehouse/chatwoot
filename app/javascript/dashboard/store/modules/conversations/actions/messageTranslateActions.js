import MessageApi from '../../../../api/inbox/message';

export default {
  async translateMessage(
    // { commit, state },
    _,
    { conversationId, messageId, targetLanguage, provider = 'google' }
  ) {
    try {
      const response = await MessageApi.translateMessage(
        conversationId,
        messageId,
        targetLanguage,
        provider
      );

      // API 응답 후 즉시 Store 업데이트
      // if (response.data) {
      //   // 현재 메시지 찾기
      //   const conversation = state.allConversations.find(
      //     c => c.id === conversationId
      //   );
      //   if (conversation) {
      //     const message = conversation.messages.find(m => m.id === messageId);
      //     if (message) {
      //       // 번역 데이터를 content_attributes에 추가
      //       const updatedMessage = {
      //         ...message,
      //         content_attributes: {
      //           ...message.content_attributes,
      //           translations: {
      //             ...message.content_attributes?.translations,
      //             [targetLanguage]: response.data.translated_content,
      //           },
      //         },
      //       };

      //       console.log('Updating message with translation:', {
      //         messageId,
      //         targetLanguage,
      //         translatedContent: response.data.translated_content,
      //         updatedMessage,
      //       });

      //       // Store 업데이트
      //       commit('ADD_MESSAGE', updatedMessage);
      //     }
      //   }
      // }

      return response.data;
    } catch (error) {
      console.error('Translation failed:', error);
      throw error;
    }
  },
};
