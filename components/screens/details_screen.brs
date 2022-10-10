sub init()
  m.title = m.top.FindNode("title")
  m.date = m.top.FindNode("date")
  'm.description = m.top.FindNode("description")
  m.layout_group = m.top.FindNode("layout_group")
  m.thumbnail = m.top.FindNode("thumbnail")
  m.postType = m.top.FindNode("postType")
  m.play_button = m.top.FindNode("play_button")
  m.resume_button = m.top.FindNode("resume_button")
  m.like_button = m.top.FindNode("like")
  m.dislike_button = m.top.FindNode("dislike")
  m.top.observeField("visible", "onVisibleChange")
  m.like_button.observeField("buttonSelected", "onLikeButtonPressed")
  m.dislike_button.observeField("buttonSelected", "onDislikeButtonPressed")
end sub

sub onVisibleChange()
  if m.top.visible = true THEN
    if m.play_button.visible = false
      m.play_button.focusable = false
      m.like_button.setFocus(true)
    else 
      m.play_button.focusable = true
      m.play_button.setFocus(true)
      if m.resume_button.focusable = true then
        m.resume_button.setFocus(true)
      end if
    end if
  end if
end sub

sub OnContentChange(obj)
  item = obj.getData()
  m.title.text = item.TITLE
  m.thumbnail.uri = item.HDPOSTERURL

  'Scrolling description to bottom would hide other video descriptions, and with no way to programmatically scroll back to the beginning, we just have to manually create/destroy the ScrollingText object
  if m.description <> invalid
    m.layout_group.removeChild(m.description)
  end if
  m.description = CreateObject("roSGNode", "ScrollableText")
  m.description.id = "description"
  m.description.font = "font:MediumSystemFont"
  m.description.color = "0xFFFFFF"
  m.description.width = "1180"
  m.description.height = "360"
  m.description.lineSpacing="4.0"
  m.description.translation="[50,200]"
  m.description.text = item.DESCRIPTION

  m.layout_group.appendChild(m.description)

  dt = createObject("roDateTime")
  dt.FromISO8601String(item.id)
  m.date.text = dt.AsDateString("short-month-short-weekday")

  m.postType.text = item.ShortDescriptionLine2

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

  'Hide or show resume button based on progress
  m.resume_button.visible = false
  m.resume_button.focusable = false
  if item.hasVideo = true
    ? "DURATION: " + item.duration.ToStr()
    ? "PROGRESS: " + item.progress.ToStr()
    if (item.progress <> 0) AND (item.progress < item.duration)
      m.resume_button.visible = true
      m.resume_button.focusable = true
      m.play_button.text = "RESTART"
      m.play_button.maxWidth = 220
      m.play_button.minWidth = 220
      m.play_button.iconUri="pkg:/images/replay.png"
      m.play_button.focusedIconUri="pkg:/images/replay.png"
      m.resume_button.maxWidth = 200
      m.resume_button.minWidth = 200
      m.resume_button.setFocus(true)
    else
      m.play_button.text = "PLAY"
      m.play_button.maxWidth = 160
      m.play_button.minWidth = 160
      m.play_button.iconUri="pkg:/images/play.png"
      m.play_button.focusedIconUri="pkg:/images/play.png"
      m.resume_button.maxWidth = 0
      m.resume_button.minWidth = 0
    end if
  end if

  'Hide or show date if media type is VOD or live
  if item.id = "live"
    m.date.visible = false
  else 
    m.date.visible = true
  end if

  'Set the number of current likes/dislikes for video
  m.like_button.text = item.likes
  m.dislike_button.text = item.dislikes
  m.likes = item.likes
  m.dislikes = item.dislikes
  m.postId = item.postId

  if item.id = "live"
    m.like_button.visible = false
    m.dislike_button.visible = false
    m.like_button.focusable = false
    m.dislike_button.focusable = false
  else
    m.like_button.visible = true
    m.dislike_button.visible = true
    m.like_button.focusable = true
    m.dislike_button.focusable = true
  end if

  'Set if user has liked or disliked video
  m.dislike_button.opacity = 0.5
  m.like_button.opacity = 0.5
  if item.userInteraction <> invalid
    for each interaction in item.userInteraction
      if interaction = "like"
        m.like_button.opacity = 1
      else if interaction = "dislike"
        m.dislike_button.opacity = 1
      end if
    end for
  end if
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
      if m.dislike_button.focusable = true
        m.dislike_button.setFocus(true)
        return true
      end if
    else if key = "right"
      if m.resume_button.focusable = true
        m.resume_button.setFocus(true)
        return true
      end if
    end if
  end if

  if m.resume_button.hasFocus()
    if key = "up"
      m.description.setFocus(true)
      return true
    else if key = "left"
      m.play_button.setFocus(true)
    end if
  end if

  if m.dislike_button.hasFocus()
    if key = "left"
      m.like_button.setFocus(true)
      return true
    else if key = "right"
      if m.play_button.visible = false
        m.play_button.focusable = false
      else 
        m.play_button.setFocus(true)
      end if
      return true
    else if key = "up"
      m.description.setFocus(true)
      return true
    end if
  end if

  if m.like_button.hasFocus()
    if key = "right"
      m.dislike_button.setFocus(true)
      return true
    else if key = "up"
      m.description.setFocus(true)
      return true
    end if
  end if

  if m.description.hasFocus()
    if key = "down"
      if m.play_button.focusable = true then
        m.play_button.setFocus(true)
      else
        m.like_button.setFocus(true)
      end if
      return true
    else if key = "back" or key = "left" or key = "right"
      if m.play_button.visible = false
        m.like_button.setFocus(true)
      else
        m.play_button.setFocus(true)
      end if
      return true
    end if
  end if

  return false
end function
