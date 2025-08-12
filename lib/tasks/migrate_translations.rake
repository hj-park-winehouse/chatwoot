namespace :translations do
  desc 'Migrate existing translation data to new structure'
  task migrate: :environment do
    puts 'Starting translation migration...'

    messages_with_translations = Message.where("content_attributes IS NOT NULL AND content_attributes->'translations' IS NOT NULL")
    total_count = messages_with_translations.count

    puts "Found #{total_count} messages with translations to migrate"

    updated_count = 0

    messages_with_translations.find_each.with_index do |message, index|
      translations = message.content_attributes['translations']

      # Skip if already migrated (translations is nil or string)
      next if translations.nil? || translations.is_a?(String)

      # Skip if translations is not a hash (unexpected format)
      next unless translations.is_a?(Hash)

      begin
        # Move existing translations to realtime_translations
        new_content_attributes = message.content_attributes.dup
        new_content_attributes['realtime_translations'] = translations
        new_content_attributes['translations'] = nil

        message.update_column(:content_attributes, new_content_attributes)
        updated_count += 1

        puts "Migrated message #{message.id} (#{index + 1}/#{total_count})" if (index + 1) % 100 == 0
      rescue StandardError => e
        puts "Error migrating message #{message.id}: #{e.message}"
      end
    end

    puts "Migration completed. Updated #{updated_count} messages."
  end

  desc 'Check translation data structure'
  task check: :environment do
    puts 'Checking translation data structure...'

    # Check messages with translations field
    translations_count = Message.where("content_attributes->'translations' IS NOT NULL").count
    translations_string_count = Message.where("content_attributes->'translations' IS NOT NULL").select do |m|
      m.content_attributes['translations'].is_a?(String)
    end.count
    translations_object_count = Message.where("content_attributes->'translations' IS NOT NULL").select do |m|
      m.content_attributes['translations'].is_a?(Hash)
    end.count

    # Check messages with realtime_translations field
    realtime_count = Message.where("content_attributes->'realtime_translations' IS NOT NULL").count

    puts 'Translation data summary:'
    puts "- Messages with translations field: #{translations_count}"
    puts "  - String format (manual): #{translations_string_count}"
    puts "  - Object format (old auto): #{translations_object_count}"
    puts "- Messages with realtime_translations field: #{realtime_count}"

    if translations_object_count > 0
      puts "\nWARNING: Found #{translations_object_count} messages with object format in translations field."
      puts "Run 'rake translations:migrate' to fix this."
    else
      puts "\nAll translations data is in correct format."
    end
  end
end
