class CHANGE_CASE {
  ; based on https://github.com/blakeembrey/change-case/blob/main/packages/change-case/src/index.ts title-case@4.3.2 38e6b4f
  static SPLIT_LOWER_UPPER_RE := "([\p{Ll}\d])(\p{Lu})"
  static SPLIT_UPPER_UPPER_RE := "(\p{Lu})([\p{Lu}][\p{Ll}])"
  static SPLIT_SEPARATE_NUMBER_RE := "(\d)\p{Ll}|(\p{L})\d"
  static DEFAULT_STRIP_REGEXP := "[^\p{L}\d]+"
  static SPLIT_REPLACE_VALUE := "$1`0$2"
  static DEFAULT_PREFIX_SUFFIX_CHARACTERS := ""

  ; Function to convert a string to camelCase (e.g., fooBar)
  static camelCase(input) {
    return CHANGE_CASE._transform(input, "camel")
  }

  ; Function to convert a string to Capital Case (e.g., Foo Bar)
  static capitalCase(input) {
    return CHANGE_CASE._transform(input, "capital", " ")
  }

  ; Function to convert a string to CONSTANT_CASE (e.g., FOO_BAR)
  static constantCase(input) {
    return CHANGE_CASE._transform(input, "upper", "_")
  }

  ; Function to convert a string to dot.case (e.g., foo.bar)
  static dotCase(input) {
    return CHANGE_CASE._transform(input, "lower", ".")
  }

  ; Function to convert a string to kebab-case (e.g., foo-bar)
  static kebabCase(input) {
    return CHANGE_CASE._transform(input, "lower", "-")
  }

  ; Function to convert a string to no case (e.g., foo bar)
  static noCase(input) {
    return CHANGE_CASE._transform(input, "lower", " ")
  }

  ; Function to convert a string to PascalCase (e.g., FooBar)
  static pascalCase(input) {
    return CHANGE_CASE._transform(input, "pascal")
  }

  ; Function to convert a string to Pascal_Snake_Case (e.g., Foo_Bar)
  static pascalSnakeCase(input) {
    return CHANGE_CASE._transform(input, "pascal", "_")
  }

  ; Function to convert a string to path/case (e.g., foo/bar)
  static pathCase(input) {
    return CHANGE_CASE._transform(input, "lower", "/")
  }

  ; Function to convert a string to sentence case (e.g., Foo bar)
  static sentenceCase(input) {
    return CHANGE_CASE._transform(input, "sentence", " ")
  }

  ; Function to convert a string to snake_case (e.g., foo_bar)
  static snakeCase(input) {
    return CHANGE_CASE._transform(input, "lower", "_")
  }

  ; Function to convert a string to Train-Case (e.g., Foo-Bar)
  static trainCase(input) {
    return CHANGE_CASE._transform(input, "capital", "-")
  }

  ; Helper function to split a string into words based on different cases
  static _split(value) {
    result := StrReplace(StrReplace(RegExReplace(value, CHANGE_CASE.SPLIT_LOWER_UPPER_RE, CHANGE_CASE.SPLIT_REPLACE_VALUE), "`0", Chr(0)), CHANGE_CASE.DEFAULT_STRIP_REGEXP, Chr(0))
    words := []
    for word in StrSplit(result, Chr(0))
      if word != ""
        words.Push(word)
    return words
  }

  ; Helper function for transforming the string into the desired case
  static _transform(input, mode, delimiter := "") {
    words := CHANGE_CASE._split(input)
    transformed := []
    lower := Func("CHANGE_CASE._lowerFactory")
    upper := Func("CHANGE_CASE._upperFactory")
    
    switch mode {
      case "camel":
        for index, word in words {
          if (index = 1)
            transformed.Push(lower.Call(word))
          else
            transformed.Push(upper.Call(SubStr(word, 1, 1)) . lower.Call(SubStr(word, 2)))
        }
      case "pascal":
        for word in words
          transformed.Push(upper.Call(SubStr(word, 1, 1)) . lower.Call(SubStr(word, 2)))
      case "capital":
        for word in words
          transformed.Push(upper.Call(SubStr(word, 1, 1)) . lower.Call(SubStr(word, 2)))
      case "upper":
        for word in words
          transformed.Push(upper.Call(word))
      case "lower":
        for word in words
          transformed.Push(lower.Call(word))
      case "sentence":
        transformed.Push(upper.Call(SubStr(words[1], 1, 1)) . lower.Call(SubStr(words[1], 2)))
        for i, word in words {
          if i > 1
            transformed.Push(lower.Call(word))
        }
    }
    return StrJoin(delimiter, transformed*)
  }

  ; Helper function for converting a string to lowercase
  static _lowerFactory(input) {
    return StrLower(input)
  }

  ; Helper function for converting a string to uppercase
  static _upperFactory(input) {
    return StrUpper(input)
  }
}