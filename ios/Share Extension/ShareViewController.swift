//
//  ShareViewController.swift
//  Share Extension
//
//  Receives files/text shared into SecuroBox from the iOS share sheet and hands
//  them to the host app. We auto-redirect (no compose UI) so the user lands
//  straight on SecuroBox's in-app Import Preview screen.
//
//  NOTE: if Xcode reports "no such module 'receive_sharing_intent'", open the
//  Runner target's Build Phases and move "Embed Foundation Extension" above
//  "Thin Binary", then clean and rebuild.
//
import receive_sharing_intent

class ShareViewController: RSIShareViewController {

    // Skip the built-in compose card and open the host app immediately with the
    // shared items — SecuroBox shows its own Import Preview screen.
    override func shouldAutoRedirect() -> Bool {
        return true
    }
}
