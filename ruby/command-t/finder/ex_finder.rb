# Copyright 2011-2014 Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

module CommandT
  class Finder
    class ExFinder < Finder
      def initialize(controller)
        @controller = controller
      end

      def sorted_matches_for(str, options = {})
        abbrev = prompt.abbrev

        # TODO: make selection expansion a command like CommandTFlush
        if abbrev.end_with?('\0') # <C-l> is overridden to add '\0' to the end of prompt.abbrev (selection expansion sentinel)
          abbrev = match_window.selection
          abbrev += ' ' unless abbrev.end_with?(
            '1', '2', '3', '4', '5', '6', '7', '8', '9', '0',
            '!', '$', '%', '(', ')', '-', '+', '\\', '|', ';', ':', ',', '.', '/'
          )
          prompt.abbrev = abbrev
          prompt.cursor_start
          prompt.cursor_end
        end

        # TODO: test simple fuzzy completion -> use abbrev.gsub(/(.)/, '*\1').gsub(/"/, '\"') and don't merge_completion
        ::VIM::command 'let d={"cmdline":""}'
        ::VIM::command 'execute "silent! normal! ' \
          ':\<C-u>' + abbrev.gsub(/"/, '\"') + '\<C-a>' \
          '\<C-\>eextend(d,{\"cmdline\":getcmdline()}).cmdline\<CR>"'
        completions = ::VIM::evaluate 'd["cmdline"]'
        return [abbrev] if completions.end_with?('') # ^A

        completions = completions.split(/(?<=[^\\])[[:space:]]+/)
        completions = completions[((abbrev + '$').split(/(?<=[^\\])[[:space:]]+/).size - 1)..-1]
        completions = completions.uniq.sort
        completions.delete_if {|completion| abbrev.downcase.include?(completion.downcase)}
        return [abbrev] if completions.empty?

        completions = completions[0..(options[:limit] - 1)]
        completions = completions.map do |completion|
          merge_completion(abbrev, completion)
        end

        return completions
      end

      def open_selection(command, selection, options = {})
        ex_command = match_window.selection
        ex_command = ex_command.gsub(/(\\)/, '\1\1')
        ex_command = ex_command.gsub(/"/, '\"')
        ::VIM::command 'call feedkeys(":\<C-u>' + ex_command + '\<CR>", "t")'
      end

    private

      def prompt
        @controller.instance_variable_get(:@prompt)
      end

      def match_window
        @controller.instance_variable_get(:@match_window)
      end

      def merge_completion(abbrev, completion)
        return completion if abbrev.empty?
        return abbrev + completion if abbrev =~ /(?<=[^\\])[[:space:]]+$/
        lowercase_prompt = abbrev.downcase
        lowercase_completion = completion.downcase
        while !lowercase_prompt.end_with?(lowercase_completion)
          lowercase_completion = lowercase_completion[0..-2]
        end
        if lowercase_completion.empty? && !lowercase_prompt.end_with?(
          '1', '2', '3', '4', '5', '6', '7', '8', '9', '0',
          '!', '$', '%', '(', '-', '+', '\\', '|', ';', ':', ',', '.'
        )
          return abbrev.split(/(?<=[^\\])[[:space:]]+/)[0..-2].join(' ') + ' ' + completion
        end
        lowercase_prompt = lowercase_prompt.chomp(lowercase_completion)
        return completion if lowercase_prompt.empty?
        return abbrev[0..(lowercase_prompt.length - 1)] + completion
      end
    end # class ExFinder
  end # class Finder
end # module CommandT
