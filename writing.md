---
layout: default
title: Writing
permalink: /writing
---

# Writing

Mostly engineering culture, infrastructure, and the occasional opinion about how teams should treat each other.

<ul class="post-list">
{% assign posts = site.posts | where: "tag", "blag" %}
{% for post in posts %}
  <li>
    <a href="{{ post.url | relative_url }}">
      <span class="post-list__title">{{ post.title }}</span>
      <span class="post-list__date">{{ post.date | date: "%Y-%m-%d" }}</span>
    </a>
  </li>
{% endfor %}
</ul>

There's an [RSS feed]({{ "/rss.xml" | relative_url }}) if you'd rather not come back.
