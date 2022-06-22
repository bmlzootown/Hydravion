sub init()
  m.title = m.top.FindNode("title")
  m.date = m.top.FindNode("date")
  m.description = m.top.FindNode("description")
  m.thumbnail = m.top.FindNode("thumbnail")
  m.postType = m.top.FindNode("postType")
  m.play_button = m.top.FindNode("play_button")
  m.like_button = m.top.FindNode("like")
  m.dislike_button = m.top.FindNode("dislike")
  m.top.observeField("visible", "onVisibleChange")
  m.like_button.observeField("buttonSelected", "onLikeButtonPressed")
  m.dislike_button.observeField("buttonSelected", "onDislikeButtonPressed")
  m.play_button.setFocus(true)
end sub

sub onVisibleChange()
  if m.top.visible = true THEN
    m.play_button.setFocus(true)
  end if
end sub

sub OnContentChange(obj)
  item = obj.getData()
  m.title.text = item.TITLE
  m.thumbnail.uri = item.HDPOSTERURL

  m.description.text = item.DESCRIPTION

  dt = createObject("roDateTime")
  dt.FromISO8601String(item.id)
  m.date.text = dt.AsDateString("short-month-short-weekday")

  m.postType.text = item.postType

  'Hide or show play button based on media type
  if item.hasPicture = true
    m.play_button.visible = false
  end if
  if item.hasAudio = true
    m.play_button.visible = true
  end if
  if item.hasVideo = true
    m.play_button.visible = true
  end if
  if item.hasAudio = false AND item.hasVideo = false
    m.play_button.visible = false
  end if

  'Set the number of current likes/dislikes for video
  m.like_button.text = item.likes
  m.dislike_button.text = item.dislikes
  m.likes = item.likes
  m.dislikes = item.dislikes
  m.postId = item.postId

  'Set if user has liked or disliked video
  m.dislike_button.opacity = 0.5
  m.like_button.opacity = 0.5
  for each interaction in item.userInteraction
    if interaction = "like"
      m.like_button.opacity = 1
    else if interaction = "dislike"
      m.dislike_button.opacity = 1
    end if
  end for
end sub

sub onLikeButtonPressed()
  if m.like_button.opacity = 0.5
    m.likes += 1
    m.like_button.opacity = 1
    m.like_button.text = m.likes
    if m.dislike_button.opacity = 1
      m.dislike_button.opacity = 0.5
      m.dislikes -= 1
      m.dislike_button.text = m.dislikes
    end if
  else if m.like_button.opacity = 1
    m.likes -= 1
    m.like_button.opacity = 0.5
    m.like_button.text = m.likes
  end if
  like_task = CreateObject("roSGNode", "likeTask")
  like_task.setField("do", "like")
  like_task.setField("id", m.postId)
  like_task.control = "RUN"
end sub

sub onDislikeButtonPressed()
  if m.dislike_button.opacity = 0.5
    m.dislikes += 1
    m.dislike_button.opacity = 1
    m.dislike_button.text = m.dislikes
    if m.like_button.opacity = 1
      m.like_button.opacity = 0.5
      m.likes -= 1
      m.like_button.text = m.likes
    end if
  else if m.dislike_button.opacity = 1
    m.dislikes -= 1
    m.dislike_button.opacity = 0.5
    m.dislike_button.text = m.dislikes
  end if
  dislike_task = CreateObject("roSGNode", "likeTask")
  dislike_task.setField("do", "dislike")
  dislike_task.setField("id", m.postId)
  dislike_task.control = "RUN"
end sub

function onKeyEvent(key as string, press as boolean) as boolean
  if not press then return false

  if m.play_button.hasFocus()
    if key = "up"
      m.description.setFocus(true)
      return true
    else if key = "left"
      m.dislike_button.setFocus(true)
      return true
    end if
  end if

  if m.dislike_button.hasFocus()
    if key = "left"
      m.like_button.setFocus(true)
      return true
    else if key = "right"
      m.play_button.setFocus(true)
      return true
    end if
  end if

  if m.like_button.hasFocus()
    if key = "right"
      m.dislike_button.setFocus(true)
      return true
    end if
  end if

  if m.description.hasFocus()
    if key = "down"
      m.play_button.setFocus(true)
      return true
    else if key = "back" or key = "left" or key = "right"
      m.play_button.setFocus(true)
      return true
    end if
  end if

  return false
end function
