# PR 85 staff chat header — stills

Dummy at `http://127.0.0.1:3000`. Each shot uses Chrome device metrics with `devicePixelRatio` 1. `window.innerWidth` matched the width in the file name.

The title measured is "New card did not stick" (scroll width 178px).

| Width | Title client width | About how much of the title shows |
|---|---|---|
| 1440 | 178px | The whole title |
| 768 | 60px | About 7 characters |
| 700 | 46px | About 6 characters (`Ne…`) |
| 640 | 0px | The split header title is squeezed out. The three desktop controls are still the ones on screen, because the chat swap starts below 640. |

At 375 the chat panel starts hidden (`display: none`) until the list opens it. The 375 menu shots open that panel, then scroll. Measured with `getBoundingClientRect` while Waiting on support was checked: kebab top 260, right 338, bottom 304, left 294 (44×44); menu top 312, right 338.4, bottom 704, left 126 (212.4×392). The menu is 8px under the kebab and the right edges match. `window.innerWidth` was 375 and `devicePixelRatio` was 1.

| File | Caption |
|---|---|
| `staff-1440-status-open.png` | Status menu open. Waiting on support is checked. |
| `staff-1440-assignee-open.png` | Assignee menu open at 1440. |
| `staff-768-status-open.png` | Status menu open at 768. The title is about 7 characters. |
| `staff-768-assignee-open.png` | Assignee menu open at 768. Avery Admin is checked. |
| `staff-700-status-open.png` | Status menu open at 700. The assignee pill says Avery. |
| `staff-700-assignee-open.png` | Assignee menu open at 700. |
| `staff-700.png` | 700 with the menus closed. Header and the form above the desk both say Waiting on support and Avery Admin. |
| `staff-640.png` | True 640. Desktop controls, not the Actions menu. The panel title has no room. |
| `staff-strip-agrees.png` | After choosing Resolved in the header. The form and the header both say Resolved and Avery Admin. |
| `staff-users-modal.png` | Jordan Lee is Requester. Avery Admin is Support staff. |
| `requester-users-modal.png` | Same roles on the signed-in conversation. |
| `requester-desktop.png` | People button only. |
| `staff-mobile-375-menu.png` | Actions menu at a true 375×812 viewport, `devicePixelRatio` 1. The conversation panel is open and the page is scrolled so the kebab is on screen. The menu sits 8px under the kebab, right edges aligned, and it does not cover the chat title. Check is on Waiting on support. |
| `staff-mobile-375-menu-customer.png` | Same 375 framing after the status is Waiting on customer. The check moves with the status. |
| `staff-mobile-375-menu-page.png` | Full page of the Waiting on support menu, so the kebab, the title, and the menu are in one frame. |
