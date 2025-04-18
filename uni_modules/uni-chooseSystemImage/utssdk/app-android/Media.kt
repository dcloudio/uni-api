package uts.sdk.modules.uniChooseSystemImage

import android.os.Parcel
import android.os.Parcelable
import android.os.Parcelable.Creator

class Media : Parcelable {
    var type: Int
    var path: String?

    constructor(type: Int, path: String?) {
        this.type = type
        this.path = path
    }

    protected constructor(`in`: Parcel) {
        type = `in`.readInt()
        path = `in`.readString()
    }

    override fun describeContents(): Int {
        return 0
    }

    override fun writeToParcel(dest: Parcel, flags: Int) {
        dest.writeInt(type)
        dest.writeString(path)
    }

    companion object {
        @JvmField
        val CREATOR: Creator<Media> = object : Creator<Media> {
            override fun createFromParcel(`in`: Parcel): Media {
                return Media(`in`)
            }

            override fun newArray(size: Int): Array<Media?> {
                return arrayOfNulls(size)
            }
        }
    }
}