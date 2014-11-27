package dk.nota.lyt.player.lock;

import android.app.PendingIntent;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.graphics.Bitmap;
import android.media.AudioManager;
import android.media.MediaMetadataRetriever;
import android.media.RemoteControlClient;
import dk.nota.lyt.Book;
import dk.nota.lyt.player.BookPlayer.EventListener;
import dk.nota.lyt.player.Event;
import dk.nota.lyt.player.PlayerApplication;
import dk.nota.lyt.player.task.AbstractTask;
import dk.nota.lyt.player.task.LoadLockScreenBookCoverTask;

public class LockScreenManager implements EventListener {
	
	private RemoteControlClient mRemoteControlClient;
	private Book  mBook;
	private Bitmap mCover;
	
	private void play(Book book) {
		
		if (mRemoteControlClient == null) {
			AudioManager audioManager = (AudioManager) PlayerApplication.getInstance().getSystemService(Context.AUDIO_SERVICE);
			audioManager.registerMediaButtonEventReceiver(getEventReceiver());
			Intent mediaButtonIntent = new Intent(Intent.ACTION_MEDIA_BUTTON);
			mediaButtonIntent.putExtra("bookId", book.getId());
			mediaButtonIntent.setComponent(getEventReceiver());
			PendingIntent mediaPendingIntent = PendingIntent.getBroadcast(PlayerApplication.getInstance(), 0, mediaButtonIntent, 0);
			// create and register the remote control client
			mRemoteControlClient = new RemoteControlClient(mediaPendingIntent);
			audioManager.registerRemoteControlClient(mRemoteControlClient);
		}
		if (mBook == null || book.getId().equals(mBook.getId()) == false) {
			mBook = book;
			mCover = null;
			new LoadLockScreenBookCoverTask().execute(new AbstractTask.SimpleTaskListener<Bitmap>() {
				
				@Override
				public void success(Bitmap result) {
					if (result != null && mRemoteControlClient != null) {
						mRemoteControlClient.editMetadata(true)
						.putBitmap(RemoteControlClient.MetadataEditor.BITMAP_KEY_ARTWORK, result)
						.apply();
					}
					mCover = result;
				}
			}, book);
		}
		
		mRemoteControlClient.setTransportControlFlags(
				RemoteControlClient.FLAG_KEY_MEDIA_PAUSE |
				RemoteControlClient.FLAG_KEY_MEDIA_PREVIOUS | 
				RemoteControlClient.FLAG_KEY_MEDIA_NEXT);
		mRemoteControlClient.setPlaybackState(RemoteControlClient.PLAYSTATE_PLAYING);
		addDefault().apply();
	}
	
	private void pause() {
		mRemoteControlClient.setPlaybackState(RemoteControlClient.PLAYSTATE_PAUSED);
		mRemoteControlClient.setTransportControlFlags(
	            RemoteControlClient.FLAG_KEY_MEDIA_PLAY |
	            RemoteControlClient.FLAG_KEY_MEDIA_PREVIOUS |
	            RemoteControlClient.FLAG_KEY_MEDIA_NEXT);
		
	}
	
	private void stop() {
		AudioManager audioManager = (AudioManager) PlayerApplication.getInstance().getSystemService(Context.AUDIO_SERVICE);
        audioManager.unregisterMediaButtonEventReceiver(getEventReceiver());
        mRemoteControlClient = null;
        mBook = null;
        mCover = null;
	}
	
	private RemoteControlClient.MetadataEditor addDefault() {
		return mRemoteControlClient.editMetadata(true)
        .putString(MediaMetadataRetriever.METADATA_KEY_ALBUM, mBook.getCurrentSection().getTitle())
        .putString(MediaMetadataRetriever.METADATA_KEY_TITLE, mBook.getTitle())
        .putBitmap(RemoteControlClient.MetadataEditor.BITMAP_KEY_ARTWORK, mCover);
        
	}

	private ComponentName getEventReceiver() {
		return new ComponentName(PlayerApplication.getInstance().getPackageName(), RemoteControlEventReceiver.class.getName());		
	}

	private void chapterChange() {
		addDefault().apply();
	}

	@Override
	public void onEvent(Event event, Book book, Object... params) {
		switch (event) {
		case PLAY_FAILED:
		case PLAY_STOP:
			pause();
			if (Boolean.TRUE.equals(params.length > 1 ? params[1] : Boolean.FALSE)) {
				stop();
			}
			break;
		case PLAY_END:
			stop();
			break;
		case PLAY_CHAPTER_CHANGE:
			chapterChange();
			break;
		case PLAY_PLAY:
			play(book);
			break;
		default:
			break;
		}
		
	}

}