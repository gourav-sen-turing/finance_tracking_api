class CategorySerializer
  include JSONAPI::Serializer

  attributes :name, :description, :color
end
