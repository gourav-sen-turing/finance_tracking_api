class BaseSerializer
  include JSONAPI::Serializer

  # Common serialization options
  set_key_transform :camel_lower
end
