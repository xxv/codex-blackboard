'use strict'
import canonical from '/lib/imports/canonical.coffee'
import { NonEmptyString } from '/lib/imports/match.coffee'
import emojify from './emoji.coffee'
import sanitize from 'sanitize-html'

params = {...sanitize.defaults}
params.allowedAttributes = {
  ...params.allowedAttributes, 
  '*': ['class'],
}

export ensureDawnOfTime = (room_name) ->
  share.model.Messages.upsert room_name,
    $min: timestamp: Date.now() - 1
    $setOnInsert:
      system: true
      dawn_of_time: true
      room_name: room_name
      bot_ignore: true
Meteor.startup ->
  ['general/0', 'callins/0', 'oplog/0'].forEach ensureDawnOfTime

export newMessage = (newMsg) ->
  check newMsg,
    body: String
    nick: NonEmptyString
    bodyIsHtml: Match.Optional Boolean
    action: Match.Optional Boolean
    to: Match.Optional NonEmptyString
    poll: Match.Optional NonEmptyString
    room_name: NonEmptyString
    useful: Match.Optional Boolean
    bot_ignore: Match.Optional Boolean
    # Present only in messages which are replies
    reply: Match.Optional
      to: NonEmptyString # ID of message this is a reply to
      # the following are copies of fields from the original message,
      # just to avoid the need to do an additional lookup when displaying
      nick: Match.Optional NonEmptyString
      body: Match.Optional String # this may be truncated, compared to original
      bodyIsHtml: Match.Optional Boolean
    # Present only in messages received via IMAP.
    # Nick will be sender's address.
    mail: Match.Optional
      sender_name: Match.Optional String
      subject: String
    # Present only in messages received via Twitter.
    # Nick will be sender's handle
    tweet: Match.Optional
      # numeric tweet ID as a string (as it's a large integer)
      id_str: NonEmptyString
      # url of tweeter's profile picture
      avatar: NonEmptyString
      # Body of quoted tweet, if this was a quote-retweet
      quote: Match.Optional NonEmptyString
      # Numeric id of quoted tweet as a string, if this was a quote-retweet
      quote_id_str: Match.Optional NonEmptyString
      # Twitter handle of tweeter of quoted tweet, if this was a quote-retweet
      quote_nick: Match.Optional NonEmptyString
  # translate emojis!
  if newMsg.bodyIsHtml
    # we don't need to sanitize because we never set bodyIsHtml on untrusted
    # content
    #newMsg.body = sanitize newMsg.body, params
    if newMsg.tweet?.quote?
      newMsg.tweet.quote = sanitize newMsg.tweet.quote, params
  else
    newMsg.body = emojify newMsg.body
  newMsg.to = canonical newMsg.to if newMsg.to?
  newMsg.timestamp = Date.now()
  # look up reply information
  if newMsg.reply?.to
    r = share.model.Messages.findOne newMsg.reply.to
    if r
        newMsg.reply.nick = r.nick
        newMsg.reply.body = r.body
        newMsg.reply.bodyIsHtml = r.bodyIsHtml
    else
        newMsg.reply = undefined
  ensureDawnOfTime newMsg.room_name
  newMsg._id = share.model.Messages.insert newMsg
  return newMsg
