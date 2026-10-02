' Helpers for the compact creator-feed payload and the post-detail payload.
' List items omit attachment arrays. Detail items return attachment objects.
' GET /api/v3/content/get/progress takes blog post ids and returns 0-100.

function contentIsNumber(value as Dynamic) as Boolean
  t = type(value)
  return t = "roInt" or t = "roFloat" or t = "roDouble" or t = "roLongInteger" or t = "Integer" or t = "LongInteger" or t = "Float" or t = "Double"
end function

function contentIsString(value as Dynamic) as Boolean
  t = type(value)
  return t = "roString" or t = "String"
end function

function contentImagePath(image as Dynamic) as String
  if type(image) <> "roAssociativeArray" then return ""
  if type(image.childImages) = "roArray" and image.childImages.Count() > 0
    child = image.childImages[0]
    if type(child) = "roAssociativeArray" and contentIsString(child.path) and child.path <> ""
      return child.path
    end if
  end if
  if contentIsString(image.path) then return image.path
  return ""
end function

function contentAttachmentId(attachment as Dynamic) as String
  if contentIsString(attachment) then return attachment
  if type(attachment) = "roAssociativeArray"
    if contentIsString(attachment.id) and attachment.id <> "" then return attachment.id
    if contentIsString(attachment.guid) and attachment.guid <> "" then return attachment.guid
  end if
  return ""
end function

function contentFirstAttachmentId(attachments as Dynamic) as String
  if type(attachments) <> "roArray" or attachments.Count() = 0 then return ""
  return contentAttachmentId(attachments[0])
end function

function contentFirstAttachmentDuration(attachments as Dynamic) as Integer
  if type(attachments) <> "roArray" or attachments.Count() = 0 then return 0
  item = attachments[0]
  if type(item) <> "roAssociativeArray" then return 0
  if contentIsNumber(item.duration) and item.duration > 0 then return Int(item.duration)
  return 0
end function

function contentPostDurationSeconds(metadata as Dynamic) as Integer
  if type(metadata) <> "roAssociativeArray" then return 0
  if contentIsNumber(metadata.displayDuration) and metadata.displayDuration > 0
    return Int(metadata.displayDuration)
  end if

  d = 0
  if contentIsNumber(metadata.videoDuration) and metadata.videoDuration <> 0
    d = metadata.videoDuration
    if contentIsNumber(metadata.videoCount) and metadata.videoCount > 0
      d = metadata.videoDuration / metadata.videoCount
    end if
  else if contentIsNumber(metadata.audioDuration) and metadata.audioDuration <> 0
    d = metadata.audioDuration
  end if
  return Int(d)
end function

function contentProgressToSeconds(percent as Dynamic, duration as Dynamic) as Integer
  if not contentIsNumber(percent) or not contentIsNumber(duration) then return 0
  if duration <= 0 or percent <= 0 then return 0
  if percent >= 100 then return Int(duration)
  return Int((percent / 100.0) * duration)
end function

function contentUserInteractions(info as Dynamic) as Object
  interactions = CreateObject("roArray", 2, true)
  if type(info) <> "roAssociativeArray" then return interactions

  if type(info.userInteraction) = "roArray"
    for each item in info.userInteraction
      if item <> invalid then interactions.Push(item)
    end for
  end if

  if contentIsString(info.selfUserInteraction) and info.selfUserInteraction <> ""
    already = false
    for each item in interactions
      if item = info.selfUserInteraction then already = true
    end for
    if not already then interactions.Push(info.selfUserInteraction)
  end if
  return interactions
end function

function contentPostBody(info as Dynamic) as String
  if type(info) <> "roAssociativeArray" then return ""
  if contentIsString(info.text) and info.text <> "" then return info.text
  if contentIsString(info.textMarkdown) then return info.textMarkdown
  if contentIsString(info.description) then return info.description
  return ""
end function
