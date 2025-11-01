# frozen_string_literal: true

module LlmDocsBuilder
  # Transforms markdown files to be AI-friendly
  #
  # Orchestrates a pipeline of specialized transformers to process markdown content.
  # Each transformer is responsible for a specific aspect of the transformation.
  #
  # @example Transform with base URL
  #   transformer = LlmDocsBuilder::MarkdownTransformer.new('README.md',
  #     base_url: 'https://myproject.io'
  #   )
  #   content = transformer.transform
  #
  # @api public
  class MarkdownTransformer
    # @return [String] path to markdown file
    attr_reader :file_path

    # @return [Hash] transformation options
    attr_reader :options

    # Initialize a new markdown transformer
    #
    # @param file_path [String] path to markdown file to transform
    # @param options [Hash] transformation options
    # @option options [String] :base_url base URL for expanding relative links
    # @option options [Boolean] :convert_urls convert HTML URLs to markdown format
    # @option options [Boolean] :remove_comments remove HTML comments from markdown
    # @option options [Boolean] :normalize_whitespace normalize excessive whitespace
    # @option options [Boolean] :remove_badges remove badge/shield images
    # @option options [Boolean] :remove_frontmatter remove YAML/TOML frontmatter
    # @option options [Boolean] :remove_code_examples remove code blocks and inline code
    # @option options [Boolean] :remove_images remove image syntax
    # @option options [Boolean] :simplify_links shorten verbose link text
    # @option options [Boolean] :remove_blockquotes remove blockquote formatting
    # @option options [Boolean] :generate_toc generate table of contents at the top
    # @option options [String] :custom_instruction custom instruction text to inject at top
    # @option options [Boolean] :remove_stopwords remove common stopwords (aggressive)
    # @option options [Boolean] :remove_duplicates remove duplicate paragraphs
    def initialize(file_path, options = {})
      @file_path = file_path
      @options = options
    end

    # Transform markdown content using a pipeline of transformers
    #
    # Processes content through specialized transformers in order:
    # 1. ContentCleanupTransformer - Removes unwanted elements
    # 2. LinkTransformer - Processes links
    # 3. HeadingTransformer - Normalizes heading hierarchy (if enabled)
    # 4. TextCompressor - Advanced compression (if enabled)
    # 5. EnhancementTransformer - Adds TOC and instructions
    # 6. WhitespaceTransformer - Normalizes whitespace
    #
    # @return [String] transformed markdown content
    def transform
      content = load_content

      # Build and execute transformation pipeline
      content = cleanup_transformer.transform(content, options)
      content = link_transformer.transform(content, options)
      content = heading_transformer.transform(content, options)
      content = compress_content(content) if should_compress?
      content = enhancement_transformer.transform(content, options)
      content = whitespace_transformer.transform(content, options)

      content
    end

    private

    # Get content cleanup transformer instance
    #
    # @return [Transformers::ContentCleanupTransformer]
    def cleanup_transformer
      @cleanup_transformer ||= Transformers::ContentCleanupTransformer.new
    end

    # Get link transformer instance
    #
    # @return [Transformers::LinkTransformer]
    def link_transformer
      @link_transformer ||= Transformers::LinkTransformer.new
    end

    # Get heading transformer instance
    #
    # @return [Transformers::HeadingTransformer]
    def heading_transformer
      @heading_transformer ||= Transformers::HeadingTransformer.new
    end

    # Get enhancement transformer instance
    #
    # @return [Transformers::EnhancementTransformer]
    def enhancement_transformer
      @enhancement_transformer ||= Transformers::EnhancementTransformer.new
    end

    # Get whitespace transformer instance
    #
    # @return [Transformers::WhitespaceTransformer]
    def whitespace_transformer
      @whitespace_transformer ||= Transformers::WhitespaceTransformer.new
    end

    # Check if content compression should be applied
    #
    # @return [Boolean]
    def should_compress?
      options[:remove_stopwords] || options[:remove_duplicates]
    end

    # Compress content using TextCompressor
    #
    # @param content [String] content to compress
    # @return [String] compressed content
    def compress_content(content)
      compressor = TextCompressor.new
      compression_methods = {
        remove_stopwords: options[:remove_stopwords],
        remove_duplicates: options[:remove_duplicates]
      }
      compressor.compress(content, compression_methods)
    end

    # Load source content either from provided string or file path
    #
    # @return [String] markdown content to transform
    def load_content
      return File.read(file_path) unless options[:content]

      content = options[:content].dup
      snippet = detection_snippet(content)

      return content if table_fragment?(snippet)
      return html_to_markdown_converter.convert(content) if html_content_snippet?(snippet)

      content
    end

    # Detect if loaded content is HTML instead of markdown
    #
    # @param content [String] raw content
    # @return [Boolean]
    def html_content?(content)
      snippet = detection_snippet(content)
      html_content_snippet?(snippet)
    end

    # Memoized HTML to markdown converter
    #
    # @return [HtmlToMarkdownConverter]
    def html_to_markdown_converter
      @html_to_markdown_converter ||= HtmlToMarkdownConverter.new
    end

    # Prepare a snippet of content for HTML detection by removing leading whitespace
    # and build metadata comments.
    #
    # @param content [String]
    # @return [String, nil]
    def detection_snippet(content)
      return unless content

      snippet = content.lstrip
      return unless snippet

      comment_prefix = /\A<!--.*?-->\s*/m
      # Remote docs often include build metadata comments; skip them before tag detection.
      while snippet.sub!(comment_prefix, '')
        return '' if snippet.empty?
      end

      snippet.lstrip[0, 500]
    end

    # Determine whether a snippet should be treated as HTML.
    #
    # @param snippet [String, nil]
    # @return [Boolean]
    def html_content_snippet?(snippet)
      return false unless snippet && !snippet.empty?

      snippet.match?(%r{<\s*(?:!DOCTYPE\s+html|html\b|body\b|head\b|article\b|section\b|main\b|p\b|div\b|table\b|thead\b|tbody\b|tr\b|td\b|th\b|meta\b|link\b|h[1-6]\b)}i)
    end

    # Detect whether the snippet represents a table fragment we should preserve.
    #
    # @param snippet [String, nil]
    # @return [Boolean]
    def table_fragment?(snippet)
      return false unless snippet && !snippet.empty?

      snippet.match?(%r{\A<\s*(?:table|thead|tbody|tr|td|th)\b}i)
    end
  end
end
